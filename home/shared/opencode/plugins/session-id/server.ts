// opencode 2.x loads every folder in plugins/ on the server too. Without this
// it would import index.tsx, the 1.x TUI entry, as a server plugin.
export default { id: "session-id", setup() {} }
