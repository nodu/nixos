# Shared module: save/restore running Claude Code & opencode sessions
#
# Provides the `nx-save-sessions` command (OneTab-style) which snapshots all
# currently running claude/opencode TUI sessions to a Markdown file and can
# reopen selected sessions into tmux windows.
#
#   nx-save-sessions            Snapshot running sessions to Markdown
#   nx-save-sessions save       (same as above)
#   nx-save-sessions restore    fzf multi-select -> relaunch into tmux windows
#   nx-save-sessions list       Print saved sessions without relaunching
#
# Save directory defaults to /Users/matt/repos/todo/ai/sessions (override with --dir).
{ config, lib, pkgs, ... }:

let
  agentSessions = pkgs.writeShellApplication {
    name = "nx-save-sessions";
    runtimeInputs = [ pkgs.python3 pkgs.lsof pkgs.fzf pkgs.tmux ];
    text = ''
      exec python3 ${../scripts/agent-sessions.py} "$@"
    '';
  };
in
{
  home.packages = [ agentSessions ];
}
