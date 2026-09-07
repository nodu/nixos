# Claude Code user config, symlinked out-of-store so Claude Code can write to
# it (permission grants, /config changes) without requiring a nix rebuild.
#
# Profile routing: work is the ABSENCE of CLAUDE_CONFIG_DIR (so it resolves to
# ~/.claude); personal sets CLAUDE_CONFIG_DIR=~/.claude-personal. That asymmetry
# is deliberate, not an oversight. The CLI derives its macOS Keychain service
# name as:
#
#   "Claude Code-credentials" + (CLAUDE_CONFIG_DIR ? "-" + sha256(dir)[0:8] : "")
#
# so setting the variable *at all* — even to ~/.claude, its own default — moves
# the credential to a different Keychain entry and forces a re-login. Leaving
# work unset keeps it on the entry it is already authenticated against.
# Everything else follows the same variable: $CLAUDE_CONFIG_DIR/.claude.json,
# settings.json, projects/, sessions/, history.jsonl.
{ config, pkgs, ... }:

let
  repo = "${config.home.homeDirectory}/repos/nixos/home/shared/claude";

  # Config both profiles share, from one source. Per-profile identity and state
  # (.claude.json, credentials, projects/, sessions/, history.jsonl) is
  # deliberately absent here — that is the half that must stay split.
  #
  # skills/, agents/ and commands/ are shared too, but by
  # ~/repos/raiz/agent-config/sync-agent-config.sh, which fans the same sources
  # out to every target listed in its TARGETS array.
  sharedFiles = [ "settings.json" "statusline.sh" ];

  linkInto = dir:
    builtins.listToAttrs (map (name: {
      name = "${dir}/${name}";
      value.source = config.lib.file.mkOutOfStoreSymlink "${repo}/${name}";
    }) sharedFiles);

  # `claude` stays bare (work). This is the only entry point that opts in to the
  # personal profile.
  claude-personal = pkgs.writeShellScriptBin "claude-personal" ''
    export CLAUDE_CONFIG_DIR="$HOME/.claude-personal"
    # Resolve via PATH first (nixpkgs on Linux, Homebrew cask on darwin), and
    # fall back for PATH-poor GUI launchers like Raycast.
    bin="$(command -v claude || true)"
    [ -n "$bin" ] || bin=/opt/homebrew/bin/claude
    exec "$bin" "$@"
  '';
in
{
  home.file = linkInto ".claude" // linkInto ".claude-personal";

  home.packages = [ claude-personal ];
}
