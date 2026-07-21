# Shared Alacritty terminal configuration
# Platform-specific overrides (package, font size, env vars, shell) should
# be set in the host's home-*.nix file.
{ config, lib, ... }:

{
  programs.alacritty = {
    enable = true;

    settings = {
      env.TERM = "xterm-256color";

      # Ctrl+1..9 => CSI-u sequences so tmux can bind C-1..C-9 for
      # Chrome-style window switching (legacy terminal encoding cannot
      # distinguish Ctrl+digit from the plain digit). The bindings live in an
      # imported raw TOML file because the ESC escape (backslash-u001b) must reach
      # Alacritty's TOML parser verbatim, which the settings generator can't
      # guarantee for control characters.
      general.import = [ "~/.config/alacritty/ctrl-num.toml" ];

      font = {
        size = lib.mkDefault 12.0;
        normal = {
          family = "Hack Nerd Font Mono";
          style = "Regular";
        };

        bold = {
          family = "Hack Nerd Font Mono";
          style = "Bold";
        };

        italic = {
          family = "Hack Nerd Font Mono";
          style = "Italic";
        };

        bold_italic = {
          family = "Hack Nerd Font Mono";
          style = "Bold Italic";
        };
      };

      cursor.style = "Block";
      window.dynamic_title = true;
      window.decorations = "Full";
      scrolling.history = 100000;

      keyboard.bindings = [
        { key = "Key0"; mods = "Control"; action = "ResetFontSize"; }
        { key = "Equals"; mods = "Control"; action = "IncreaseFontSize"; }
        { key = "Minus"; mods = "Control"; action = "DecreaseFontSize"; }
        { key = "F"; mods = "Shift|Alt"; action = "SearchBackward"; }
        # Shift+Alt: plain Alt+V must pass through to tmux, which binds M-v
        # to copy-mode (the "vim mode" used day-to-day; see tmux.nix). This
        # terminal-level vi mode is the fallback for bare alacritty.
        { key = "V"; mods = "Shift|Alt"; action = "ToggleViMode"; }
        { key = "N"; mods = "Shift|Control"; action = "CreateNewWindow"; }
      ];

      colors = with config.colorScheme.palette; {
        draw_bold_text_with_bright_colors = true;
        cursor = {
          cursor = "0x${base06}";
          text = "0x${base00}";
        };
        vi_mode_cursor = {
          cursor = "0x${base07}";
          text = "0x${base00}";
        };
        hints = {
          start = {
            foreground = "0x${base00}";
            background = "0x${base0A}";
          };
          end = {
            foreground = "0x${base00}";
          };
        };
        selection = {
          text = "0x${base00}";
          background = "0x${base06}";
        };
        search.matches = {
          foreground = "0x${base00}";
        };
        footer_bar = {
          foreground = "0x${base00}";
        };
        search.focused_match = {
          foreground = "0x${base00}";
          background = "0x${base0B}";
        };
        primary = {
          background = "0x${base00}";
          foreground = "0x${base05}";
          dim_foreground = "0x${base05}";
          bright_foreground = "0x${base05}";
        };
        indexed_colors = [
          {
            index = 16;
            color = "0x${base09}";
          }
          {
            index = 17;
            color = "0x${base06}";
          }
        ];
        normal = {
          black = "0x${base03}";
          white = "0x${base06}";
          blue = "0x${base0D}";
          cyan = "0x${base0C}";
          green = "0x${base0B}";
          magenta = "0x${base0E}";
          red = "0x${base08}";
          yellow = "0x${base0A}";
        };
        bright = {
          black = "0x${base00}";
          white = "0x${base06}";
          blue = "0x${base0D}";
          cyan = "0x${base0C}";
          green = "0x${base0B}";
          magenta = "0x${base0E}";
          red = "0x${base08}";
          yellow = "0x${base09}";
        };
      };
    };
  };

  # Raw binding file imported by alacritty above. Written verbatim (nix ''..''
  # does not treat \u as an escape), so Alacritty parses the TOML
  # backslash-u001b escapes into real ESC bytes. Ctrl+N sends CSI-u <codepoint>;5u, which tmux
  # decodes as C-N for the window-switching binds in tmux.nix.
  # Ctrl+/ is bound the same way: Alacritty on macOS drops the Ctrl modifier
  # and emits a bare "/", so nvim never sees the key. tmux decodes 47;5u as
  # C-/ and re-encodes per pane (0x1f legacy, CSI 27;5;47~ for nvim).
  xdg.configFile."alacritty/ctrl-num.toml".text = ''
    keyboard.bindings = [
      { key = "1", mods = "Control", chars = "\u001b[49;5u" },
      { key = "2", mods = "Control", chars = "\u001b[50;5u" },
      { key = "3", mods = "Control", chars = "\u001b[51;5u" },
      { key = "4", mods = "Control", chars = "\u001b[52;5u" },
      { key = "5", mods = "Control", chars = "\u001b[53;5u" },
      { key = "6", mods = "Control", chars = "\u001b[54;5u" },
      { key = "7", mods = "Control", chars = "\u001b[55;5u" },
      { key = "8", mods = "Control", chars = "\u001b[56;5u" },
      { key = "9", mods = "Control", chars = "\u001b[57;5u" },
      { key = "/", mods = "Control", chars = "\u001b[47;5u" },
    ]
  '';
}
