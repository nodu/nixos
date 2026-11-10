// Expose the Claude Code plugin cache to opencode's shell tool.
//
// The Overroute skills (loaded via `skills.paths` in opencode.base.json) reference
// `${CLAUDE_PLUGIN_ROOT}` in their shell snippets to reach `_shared/` canon and
// scripts. Claude Code sets that var per-plugin at runtime; opencode has no
// plugin-marketplace equivalent, so we point it at the stable
// `~/.claude/skills-overroute` symlink maintained by sync-agent-config.sh.
//
// This hook runs for every shell the tool spawns, so the var is present
// regardless of how opencode was launched (login shell, GUI, etc.) — no
// reliance on .zshrc.
//
// One default export serves both majors: opencode 2.x calls setup(), 1.x calls
// server(). Nothing is imported so it loads on either; drop server() once no
// host runs 1.x.

const root = () => `${process.env.HOME}/.claude/skills-overroute`

export default {
  id: "claude-plugin-root",
  async setup(ctx: any) {
    await ctx.shell.hook("create.before", (event: any) => {
      event.env.CLAUDE_PLUGIN_ROOT = root()
    })
  },
  async server() {
    return {
      "shell.env": async (_input: unknown, output: any) => {
        output.env.CLAUDE_PLUGIN_ROOT = root()
      },
    }
  },
}
