# opencode user config, symlinked out-of-store so it can be edited without a
# nix rebuild. Only opencode.json is managed: commands/ and skills/ in
# ~/.config/opencode are symlinks maintained by repos/raiz/agent-config, and
# auth/state live in ~/.local/share/opencode (secrets, never in this repo).
{ config, ... }:

{
  xdg.configFile."opencode/opencode.json".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/repos/nixos/home/shared/opencode/opencode.json";
}
