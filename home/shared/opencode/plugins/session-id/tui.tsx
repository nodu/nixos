/** @jsxImportSource @opentui/solid */

// opencode 2.x entry for the session-id plugin; index.tsx is the 1.x entry.
// Delete index.tsx and server.ts once no host runs 1.x.

export default {
  id: "session-id",
  setup(context) {
    return context.ui.slot({
      append: "prompt.footer",
      render: (input) => (
        <text fg={context.theme.textMuted}>
          {input.sessionID ? `opencode -s ${input.sessionID}` : ""}
        </text>
      ),
    })
  },
}
