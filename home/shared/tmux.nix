# Shared tmux configuration
{ config, lib, pkgs, ... }:

let
  # nix-colors palette (Catppuccin Mocha on both hosts), hex without '#'.
  # Used to pin the theme to the terminal scheme instead of ANSI names.
  p = config.colorScheme.palette;

  # fzf picker for the prefix+Space bind below. A separate script rather than an
  # inline popup command: display-popup format-expands #{...} in its
  # argument, and nix/tmux/sh quoting three levels deep is fragile.
  # Cancelling fzf (Esc) exits 130, so `|| exit 0` makes dismissal silent.
  fzfWindow = pkgs.writeShellScript "tmux-fzf-window" ''
    target=$(tmux list-windows -a -F '#{session_name}:#{window_index}  #{window_name}  #{pane_title}' \
      | ${pkgs.fzf}/bin/fzf --reverse --header 'find window' \
      | awk '{print $1}') || exit 0
    [ -n "$target" ] && tmux switch-client -t "$target"
  '';

  # Sibling of fzfWindow: fuzzy-pick where to send the current pane. The list
  # is every window except the current one (moving a pane into its own window
  # is pointless), plus a synthetic "＋ new window" row at the top. Picking a
  # window joins the pane into it; picking the new-window row pops the pane out
  # into a fresh window (break-pane). Both follow focus to the pane's new home.
  # Cancelling fzf (Esc) exits 130, so `|| exit 0` makes dismissal silent.
  fzfMovePane = pkgs.writeShellScript "tmux-fzf-move-pane" ''
    current=$(tmux display-message -p '#{session_name}:#{window_index}')
    choice=$( { echo '__new__  ＋ new window'; \
      tmux list-windows -a -F '#{session_name}:#{window_index}  #{window_name}  #{pane_title}' \
        | grep -v "^$current  "; } \
      | ${pkgs.fzf}/bin/fzf --reverse --header 'move pane to window' \
      | awk '{print $1}') || exit 0
    case "$choice" in
      "") ;;
      __new__) tmux break-pane ;;
      *) tmux join-pane -t "$choice" ;;
    esac
  '';

  # Single source of truth for the custom prefix bindings. Each entry generates
  # BOTH its `bind -N` line and a row in the fzf command palette (prefix + ?), so
  # the two can never drift. Two action shapes:
  #   cmd   — a raw tmux command; the bind runs it, the palette runs `tmux <cmd>`.
  #           Must be valid both as a tmux config command and after `tmux ` in sh
  #           (true for all of ours — tmux/sh quoting agrees for these).
  #   popup — a script; the bind wraps it in display-popup, the palette `exec`s it
  #           so its fzf runs in THIS popup's terminal (no display-popup nesting).
  # `desc` is used verbatim as the `-N` note and the palette label.
  customBinds = [
    # fzf sibling pickers (see fzfMovePane / fzfWindow above). ! replaces the
    # default break-pane bind; Space replaces the unused next-layout bind.
    { key = "!";     desc = "Move pane to window (fzf)"; popup = fzfMovePane; }
    { key = "Space"; desc = "Find window (fzf)";         popup = fzfWindow; }
    # Pane zoom on f: default z is a stretch from C-a, and f's default
    # (find-window) is superseded by the fzf finder. (`unbind z` stays below.)
    { key = "f";     desc = "Zoom / unzoom pane";          cmd = "resize-pane -Z"; }
    # Reorder: < / > nudge the current window one slot (-r repeatable, -d keeps
    # focus on the moved window).
    { key = "<";     desc = "Move window left";  cmd = "swap-window -d -t -1"; repeat = true; }
    { key = ">";     desc = "Move window right"; cmd = "swap-window -d -t +1"; repeat = true; }
    # Splits / new window open in the active pane's directory.
    { key = "|";     desc = "Split pane right (same dir)"; cmd = ''split-window -h -c "#{pane_current_path}"''; }
    { key = "-";     desc = "Split pane down (same dir)";  cmd = ''split-window -v -c "#{pane_current_path}"''; }
    { key = "n";     desc = "New window (same dir)";       cmd = ''new-window -c "#{pane_current_path}"''; }
    # `\; display …` chains a confirmation toast. Dual-valid: as a tmux config
    # line `\;` separates the two commands; in the palette's `tmux …` shell call
    # `\;` passes a literal `;` arg (tmux's CLI command separator) and the quoted
    # message stays a single arg — so both the bind and the palette show it.
    { key = "r";     desc = "Reload tmux config";          cmd = ''source-file ~/.config/tmux/tmux.conf \; display "Config reloaded"''; }
    # Chrome-style insert: -b places the window before the given index and shifts
    # the rest right; past the last window -b no-ops so fall back to a plain move,
    # which renumber-windows compacts to the end. %1 (not %%) so the single prompt
    # response fills the one slot. (m replaces the unused mark-pane bind.)
    { key = "m";     desc = "Move window to index";
      cmd = ''command-prompt -p "move window to:" 'if -F "#{e|<=:%1,#{session_windows}}" "move-window -b -t :%1" "move-window -t :%1"' ''; }
  ];

  # Generators over customBinds ------------------------------------------------
  mkBindLine = b:
    let action = if b ? popup
                 then "display-popup -E -w 70% -h 50% ${b.popup}"
                 else b.cmd;
    in ''bind ${lib.optionalString (b.repeat or false) "-r "}-N "${b.desc}" "${b.key}" ${action}'';
  customBindLines = lib.concatMapStringsSep "\n      " mkBindLine customBinds;

  # fzf command palette bound to prefix + ?: search the custom commands, run the
  # selection on Enter. Rows are "<key> · <desc>"; the key is the first token, so
  # the case matches on it. Popup entries are exec'd (fzf reuses this terminal);
  # direct entries run then fall through, closing the popup (-E). Esc = 130 → || exit 0.
  # A trailing "⋯" row (not a bind — palette-only) pipes the full built-in
  # list-keys reference into fzf so it's searchable, so overriding `?` doesn't
  # lose the old help. Browse-only: Enter just closes (executing an arbitrary
  # selected default bind is the brittle replay path we avoid).
  paletteRows  = lib.concatMapStringsSep " \\\n      " (b: ''"${b.key} · ${b.desc}"'') customBinds;
  paletteCases = lib.concatMapStringsSep "\n      " (b:
    ''"${b.key}") ${if b ? popup then "exec ${b.popup}" else "tmux ${b.cmd}"} ;;'') customBinds;
  tmuxHelp = pkgs.writeShellScript "tmux-help" ''
    sel=$(printf '%s\n' \
      ${paletteRows} \
      "⋯ · All tmux key bindings" \
      | ${pkgs.fzf}/bin/fzf --reverse --header 'run command (enter)') || exit 0
    case "$(printf '%s' "$sel" | awk '{print $1}')" in
      ${paletteCases}
      "⋯") tmux list-keys -N | ${pkgs.fzf}/bin/fzf --reverse --header 'all key bindings (search only)' >/dev/null || true ;;
    esac
  '';
in
{
  programs.tmux = {
    enable = true;
    prefix = "C-a";
    escapeTime = 0;
    terminal = "tmux-256color";
    keyMode = "vi";
    mouse = true;
    baseIndex = 1;
    historyLimit = 50000;
    customPaneNavigationAndResize = true;
    # Terminal focus events: useful for vim autoread etc., and required for
    # tmux to track which client is focused (the "focused" client flag),
    # which aerospace/tmux-nav.sh uses to drive the right tmux client when
    # multiple terminal windows are open. NOTE: the module default emits
    # `set -g focus-events off`, so this must stay on here (not just in
    # extraConfig) — a config reload with it off would break tmux-nav.
    focusEvents = true;

    # Session persistence across reboots: resurrect saves/restores sessions
    # (windows, panes, layouts, cwd), continuum autosaves on an interval and
    # restores automatically when the tmux server starts. Order matters:
    # continuum must load after resurrect. home-manager emits plugin loads
    # BEFORE extraConfig, and continuum arms autosave by prepending a
    # #(continuum_save.sh) hook to the status-right value it finds at load
    # time — so status-right gets its final value here and must NOT be set
    # again in extraConfig, or the hook is clobbered and autosave silently
    # dies. Verify with: tmux show -g status-right (must mention continuum).
    plugins = with pkgs.tmuxPlugins; [
      {
        plugin = resurrect;
        extraConfig = ''
          set -g @resurrect-capture-pane-contents 'on'
        '';
      }
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval '10'

          # status-right lives here, not in the theme block: see plugin
          # ordering comment above.
          set -g status-right-style 'fg=#${p.base00} bg=#${p.base0A}'
          set -g status-right ' #{=21:pane_title} '
          set -g status-right-length 50
        '';
      }
    ];

    extraConfig = ''
      # home-manager binds send-prefix in the ROOT table (bind -n <prefix>),
      # which hijacks the key so it fires send-prefix on every press and never
      # acts as the prefix. Undo that and rebind send-prefix into the prefix
      # table (so C-a C-a still sends a literal C-a through).
      unbind -n C-a
      bind C-a send-prefix

      # True color support
      set -ag terminal-overrides ",xterm-256color:RGB"

      # Set terminal window titles (programs in panes may override via
      # passthrough — cosmetic only, nothing depends on titles).
      set -g set-titles on
      set -g set-titles-string 'tmux #S:#W'

      # Vi copy-mode bindings
      bind -T copy-mode-vi v send -X begin-selection
      bind -T copy-mode-vi y send -X copy-selection-and-cancel

      # Mouse wheel routing: pass events to apps that handle the mouse
      # themselves (less --mouse, vim, TUIs); for alternate-screen apps
      # that don't, send arrow keys instead (what the terminal does natively
      # outside tmux); otherwise scroll tmux history via copy-mode.
      bind -n WheelUpPane if -F '#{||:#{pane_in_mode},#{mouse_any_flag}}' 'send -M' "if -F '#{alternate_on}' 'send -N3 Up' 'copy-mode -e; send -M'"
      bind -n WheelDownPane if -F '#{||:#{pane_in_mode},#{mouse_any_flag}}' 'send -M' "if -F '#{alternate_on}' 'send -N3 Down' 'send -M'"

      # Esc dismisses prompts (command prompt, copy-mode search): keyMode=vi
      # makes home-manager set status-keys vi too, where Esc enters a vi
      # normal-mode at the prompt instead of canceling it.
      set -g status-keys emacs
      # Esc also leaves copy mode entirely (default Esc only clears the
      # selection; q was the only way out).
      bind -T copy-mode-vi Escape send -X cancel

      # Alt+V enters copy mode, matching Alacritty's vi-mode key so "vim
      # mode" is one keystroke everywhere. Requires the terminal to pass
      # Alt through (option_as_alt/macos-option-as-alt on the mac host) and
      # Alacritty to NOT bind plain Alt+V itself — its own ToggleViMode
      # lives on Shift+Alt+V for that reason (see alacritty.nix).
      bind -n M-v copy-mode

      # Custom prefix bindings — splits, new window, reload, the fzf pickers,
      # window reorder/move, zoom — are generated from the `customBinds` list in
      # the let block above, which ALSO generates the fzf command palette bound
      # to prefix + ? (search + run on Enter). One source, so a bind and its
      # palette row can't drift. Per-command rationale lives on that list.
      ${customBindLines}

      # c mirrors n (new window in cwd) but is kept off the palette to avoid a
      # duplicate row; it overrides tmux's default new-window bind.
      bind -N "New window (same dir)" c new-window -c "#{pane_current_path}"

      # prefix + ? opens the fzf command palette, replacing the default list-keys.
      bind -N "Command palette" ? display-popup -E -w 70% -h 70% ${tmuxHelp}

      # f's zoom (generated above) frees z, whose default zoom is a stretch from C-a.
      unbind z

      # Chrome-style window switching: Ctrl+1..9 jumps straight to that window.
      # Needs extended keys — in the legacy encoding Ctrl+digit is
      # indistinguishable from the plain digit, so tmux must ask the outer
      # terminal (Alacritty/Ghostty, via CSI-u) to encode them distinctly.
      set -s extended-keys on
      set -as terminal-features 'xterm*:extkeys'

      # Pass OSC 8 hyperlinks (Claude Code, opencode, ls --hyperlink) through
      # to the outer terminal instead of stripping them; open with Shift+click
      # in Alacritty, Cmd+click in Ghostty.
      set -as terminal-features '*:hyperlinks'
      bind -n C-1 select-window -t :1
      bind -n C-2 select-window -t :2
      bind -n C-3 select-window -t :3
      bind -n C-4 select-window -t :4
      bind -n C-5 select-window -t :5
      bind -n C-6 select-window -t :6
      bind -n C-7 select-window -t :7
      bind -n C-8 select-window -t :8
      bind -n C-9 select-window -t :9

      # Browser-tab numbering: windows start at 1 (so Ctrl+1 is the first
      # tab — Ctrl+0 stays reset-zoom in the terminal) and renumber on
      # close, so killing window 2 of 1/2/3 slides 3 down into its slot.
      set -g base-index 1
      set -g renumber-windows on

      # Window reorder (< / >) and move-to-index (m) are generated from
      # customBinds above (see there for the -b Chrome-insert / renumber logic).

      # Theme: red/yellow/black, pinned to the nix-colors palette so tmux
      # matches the terminal scheme exactly and renders identically in
      # Alacritty and Ghostty. Dark text on colored chips must be base00
      # (the true background): ANSI "black" is remapped to surface1
      # (#45475a) in the Alacritty palette, which reads as muddy gray on
      # the pastel red/yellow backgrounds.
      setw -g mode-style 'fg=#${p.base00} bg=#${p.base08} bold'

      # Borders are colored per adjacent pane, so inactive must contrast
      # hard with active or shared border lines read as ambiguous.
      # Catppuccin Mocha overlay0 — the palette's brightblack (#45475a) is
      # near-invisible against the Mocha background.
      set -g pane-border-style 'fg=#6c7086'
      set -g pane-active-border-style 'fg=#${p.base08},bold'
      set -g pane-border-indicators both

      set -g pane-border-status top
      set -g pane-border-format '#{?pane_active,#[fg=#${p.base00} bg=#${p.base08} bold] #P #{pane_current_command} #[default],}'

      set -g status-position bottom
      set -g status-justify left
      set -g status-style 'fg=#${p.base08} bg=default'
      set -g status-left ""
      # status-right is set in the continuum plugin block above — setting it
      # here would clobber continuum's autosave hook.

      setw -g window-status-current-style 'fg=#${p.base00} bg=#${p.base08} bold'
      setw -g window-status-current-format ' #I #W #{s/Z/F/;s/\*//:window_flags} '

      setw -g window-status-style 'fg=#${p.base08} bg=#${p.base02}'
      setw -g window-status-format ' #I #[fg=#${p.base05}]#W #[fg=#${p.base0A}]#{s/Z/F/:window_flags} '

      setw -g window-status-bell-style 'fg=#${p.base00} bg=#${p.base09} bold'

      set -g message-style 'fg=#${p.base00} bg=#${p.base0A} bold'
    '';
  };
}
