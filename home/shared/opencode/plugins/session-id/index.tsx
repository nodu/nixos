/** @jsxImportSource @opentui/solid */

// opencode TUI plugin: show the copy-pasteable resume command for the current
// session on the prompt row, so a pane restored after a crash can be relaunched
// by reading the command straight off the screen.
//
// Renders `opencode -s <session_id>` into the `session_prompt_right` slot,
// which the host populates with `{ session_id }` for the active session.
//
// Dependency-free: opencode's Bun runtime transpiles this .tsx and configures
// the @opentui/solid runtime for plugin modules, so no package.json or
// node_modules is needed. This plugin is declared in tui.json (not
// opencode.json) so only the TUI pass loads it — the server pass never sees it.

const tui = async (api) => {
  api.slots.register({
    order: 50,
    slots: {
      session_prompt_right(context, input) {
        if (!input?.session_id) return null
        return <text fg={context.theme.current.textMuted}>opencode -s {input.session_id}</text>
      },
    },
  })
}

export default { id: "session-id", tui }
