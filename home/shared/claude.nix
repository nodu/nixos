# Claude Code user config, symlinked out-of-store so Claude Code can write to
# it (permission grants, /config changes) without requiring a nix rebuild.
{ config, ... }:

{
  home.file = {
    ".claude/settings.json".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/repos/nixos/home/shared/claude/settings.json";
    ".claude/statusline.sh".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/repos/nixos/home/shared/claude/statusline.sh";
  };
}
