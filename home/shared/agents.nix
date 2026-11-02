# Global agent instructions, one source for every harness. Each reads its own
# filename from its own config dir, so home/shared/agents/AGENTS.md is linked
# out-of-store into all of them (edits apply without a rebuild):
#
#   Claude Code  ~/.claude/CLAUDE.md, ~/.claude-personal/CLAUDE.md
#   opencode     ~/.config/opencode/AGENTS.md
#   Codex        ~/.codex/AGENTS.md
#
# These are loaded into every session's context, which is as close to a system
# prompt as works everywhere: --append-system-prompt style flags are skipped
# when a GUI (T3 Code, Raycast) launches the CLI itself.
{ config, ... }:

let
  source = config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/repos/nixos/home/shared/agents/AGENTS.md";
in
{
  home.file.".claude/CLAUDE.md".source = source;
  home.file.".claude-personal/CLAUDE.md".source = source;
  home.file.".codex/AGENTS.md".source = source;
  xdg.configFile."opencode/AGENTS.md".source = source;
}
