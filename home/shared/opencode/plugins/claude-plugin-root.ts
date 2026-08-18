// Expose the Claude Code plugin cache to opencode's bash tool.
//
// The Overroute skills (loaded via `skills.paths` in opencode.json) reference
// `${CLAUDE_PLUGIN_ROOT}` in their shell snippets to reach `_shared/` canon and
// scripts. Claude Code sets that var per-plugin at runtime; opencode has no
// plugin-marketplace equivalent, so we point it at the stable
// `~/.claude/skills-overroute` symlink maintained by sync-agent-config.sh.
//
// This hook runs for every shell the bash tool spawns, so the var is present
// regardless of how opencode was launched (login shell, GUI, etc.) — no
// reliance on .zshrc.

import type { Plugin } from "@opencode-ai/plugin"

// opencode runs this in its Bun runtime, which provides `process.env` natively.
// (A bare `tsc --noEmit` flags `process`/`node:*` only because bun-types isn't
// installed in this config dir; it's not a runtime issue.)
const ClaudePluginRoot: Plugin = async () => ({
  "shell.env": async (_input, output) => {
    output.env.CLAUDE_PLUGIN_ROOT = `${process.env.HOME}/.claude/skills-overroute`
  },
})

export default ClaudePluginRoot
