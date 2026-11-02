#!/usr/bin/env python3
"""Write the shared MCP server list into Claude Code's user scope.

The source is ~/.config/mcp/servers.json (home/shared/mcp/servers.json in this
repo). Claude Code has no file it reads user-scope servers from -- they live in
$CLAUDE_CONFIG_DIR/.claude.json, which is also its mutable state -- so each
profile's mcpServers block is updated in place instead of symlinked.

Only servers this script added are touched: names it wrote are recorded in
~/.local/state/nx-mcp-sync/managed.json, so a server removed from servers.json
is removed from Claude too, while servers added by hand with `claude mcp add`
are left alone.

Tokens never reach .claude.json. A server with an authFile gets a headersHelper
that reads the file each time Claude connects, which also means rotating a token
is just rewriting the file.

opencode is not handled here: its config is a generated file with one writer,
nx-opencode-models-sync, which merges servers.json itself.

    nx-mcp-sync            # update every Claude profile that exists
    nx-mcp-sync --print    # show the entries instead of writing
"""

import argparse
import json
import os
import shlex
import sys
import tempfile

HOME = os.path.expanduser("~")
DEFAULT_SERVERS = os.path.join(HOME, ".config/mcp/servers.json")
STATE = os.path.join(HOME, ".local/state/nx-mcp-sync/managed.json")

# Work is ~/.claude.json (CLAUDE_CONFIG_DIR unset), personal is
# ~/.claude-personal/.claude.json -- see home/shared/claude.nix.
PROFILES = [
    os.path.join(HOME, ".claude.json"),
    os.path.join(HOME, ".claude-personal/.claude.json"),
]


def load_servers(path: str) -> dict:
    try:
        with open(path) as handle:
            servers = json.load(handle).get("mcpServers")
    except FileNotFoundError:
        raise SystemExit(f"error: server list not found: {path}")
    except json.JSONDecodeError as exc:
        raise SystemExit(f"error: {path} is not valid JSON: {exc}")
    if not isinstance(servers, dict):
        raise SystemExit(f"error: {path} has no mcpServers object")
    return servers


def claude_entry(server: dict, auth_helper: str) -> dict:
    if "command" in server:
        entry = {"type": "stdio", "command": server["command"]}
        for key in ("args", "env"):
            if key in server:
                entry[key] = server[key]
        return entry

    entry = {"type": server.get("type", "http"), "url": server["url"]}
    if "authFile" in server:
        auth_file = os.path.expanduser(server["authFile"])
        if not os.path.exists(auth_file):
            print(f"warning: {auth_file} is missing", file=sys.stderr)
        entry["headersHelper"] = f"{auth_helper} {shlex.quote(auth_file)}"
    return entry


def write_json(path: str, data: dict) -> None:
    """Atomic replace that keeps the file's mode (.claude.json is 0600)."""
    mode = os.stat(path).st_mode & 0o777 if os.path.exists(path) else 0o600
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".nx-mcp-sync.")
    with os.fdopen(fd, "w") as handle:
        json.dump(data, handle, indent=2, ensure_ascii=False)
        handle.write("\n")
    os.chmod(tmp, mode)
    os.replace(tmp, path)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--servers", default=DEFAULT_SERVERS)
    parser.add_argument(
        "--auth-helper",
        default="nx-mcp-auth-header",
        help="command that prints {Authorization: <file contents>} for a file",
    )
    parser.add_argument("--print", dest="to_stdout", action="store_true")
    args = parser.parse_args()

    entries = {
        name: claude_entry(server, args.auth_helper)
        for name, server in load_servers(args.servers).items()
    }

    if args.to_stdout:
        print(json.dumps(entries, indent=2))
        return 0

    try:
        with open(STATE) as handle:
            managed = json.load(handle)
    except (FileNotFoundError, json.JSONDecodeError):
        managed = {}

    for profile in PROFILES:
        if not os.path.exists(profile):
            continue  # profile never launched; Claude creates the file itself

        with open(profile) as handle:
            config = json.load(handle)
        current = config.setdefault("mcpServers", {})

        stale = set(managed.get(profile, [])) - entries.keys()
        for name in stale:
            current.pop(name, None)
        current.update(entries)

        write_json(profile, config)
        managed[profile] = sorted(entries)
        removed = f", removed {', '.join(sorted(stale))}" if stale else ""
        print(f"wrote {len(entries)} server(s) to {profile}{removed}")

    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    write_json(STATE, managed)
    return 0


if __name__ == "__main__":
    sys.exit(main())
