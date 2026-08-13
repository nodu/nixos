# opencode user config, symlinked out-of-store so it can be edited without a
# nix rebuild. Managed here: opencode.json (server/runtime), tui.json (TUI
# plugins), and plugins/ (TUI slot plugins, e.g. the session-id resume-line).
# commands/ and skills/ in ~/.config/opencode are symlinks maintained by
# repos/raiz/agent-config, and auth/state live in ~/.local/share/opencode
# (secrets, never in this repo).
{ config, ... }:

{
  xdg.configFile."opencode/opencode.json".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/repos/nixos/home/shared/opencode/opencode.json";

  # TUI config: declares TUI-only plugins (kept out of opencode.json so the
  # server plugin pass never tries to load a tui-only module).
  xdg.configFile."opencode/tui.json".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/repos/nixos/home/shared/opencode/tui.json";

  # TUI slot plugins (loaded via the `plugin` array in tui.json).
  xdg.configFile."opencode/plugins".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/repos/nixos/home/shared/opencode/plugins";
}
