# opencode user config, symlinked out-of-store so it can be edited without a
# nix rebuild. Managed here: opencode.json (server/runtime), tui.json (TUI
# plugins), and plugins/ (TUI slot plugins, e.g. the session-id resume-line).
# commands/ and skills/ in ~/.config/opencode are symlinks maintained by
# repos/raiz/agent-config, and auth/state live in ~/.local/share/opencode
# (secrets, never in this repo).
#
# The ollama provider block is deliberately NOT in opencode.json: the installed
# model set differs per host and changes on every pull/rm, so it is generated
# from the local ollama store by `nx-opencode-ollama-sync` into
# ~/.config/opencode/ollama.local.json. opencode merges config sources in
# order (global -> OPENCODE_CONFIG -> project), so pointing OPENCODE_CONFIG at
# the generated file layers the host's real models over the shared settings
# below without either file duplicating the other.
{ config, pkgs, ... }:

let
  opencodeOllamaSync = pkgs.writeShellApplication {
    name = "nx-opencode-ollama-sync";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      exec python3 ${../scripts/opencode-ollama-models.py} "$@"
    '';
  };
in
{
  home.packages = [ opencodeOllamaSync ];

  home.sessionVariables.OPENCODE_CONFIG =
    "${config.xdg.configHome}/opencode/ollama.local.json";

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
