# MCP servers shared by every agent harness, declared once in
# home/shared/mcp/servers.json and symlinked out-of-store to
# ~/.config/mcp/servers.json so edits land without a rebuild.
#
# No harness reads that file directly; each has its own format and location:
#
#   Claude Code  nx-mcp-sync writes the servers into the user scope of both
#                profiles ($CLAUDE_CONFIG_DIR/.claude.json). That file is also
#                Claude's mutable state, so it is updated in place, not linked.
#   opencode     nx-opencode-models-sync merges them into opencode.json, which
#                it already generates (home/shared/opencode.nix).
#
# Secrets: each server's authFile (~/.secrets/mcp/<name>, mode 0600) holds the
# whole Authorization header value, e.g. "Bearer <token>" or "Basic <base64>".
# Neither generated config contains it: Claude gets a headersHelper that runs
# nx-mcp-auth-header on the file at connect time, opencode a {file:...}
# reference. ~/.secrets is covered by `make secrets/backup`.
#
# Rerun `nx-mcp-sync` and `nx-opencode-models-sync` by hand after editing
# servers.json; a switch runs both.
{ config, lib, pkgs, ... }:

let
  authHeader = pkgs.writeShellApplication {
    name = "nx-mcp-auth-header";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      jq -n --rawfile value "$1" '{Authorization: ($value | rtrimstr("\n"))}'
    '';
  };

  # The helper is referenced by store path so it works from GUI-launched
  # clients whose PATH lacks the home-manager profile.
  mcpSync = pkgs.writeShellApplication {
    name = "nx-mcp-sync";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      exec python3 ${../scripts/mcp-sync.py} \
        --auth-helper ${authHeader}/bin/nx-mcp-auth-header "$@"
    '';
  };
in
{
  home.packages = [ authHeader mcpSync ];

  xdg.configFile."mcp/servers.json".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/repos/nixos/home/shared/mcp/servers.json";

  home.activation.mcpSync =
    lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      $DRY_RUN_CMD ${mcpSync}/bin/nx-mcp-sync \
        || echo "warning: nx-mcp-sync failed; Claude Code MCP servers not refreshed" >&2
    '';
}
