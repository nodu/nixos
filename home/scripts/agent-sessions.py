#!/usr/bin/env python3
"""OneTab-style save/restore for running Claude Code and opencode sessions.

Detects currently-running `claude` / `opencode` TUI sessions, resolves each to
its on-disk session and working directory, and writes a Markdown snapshot with
copy-pasteable resume commands. Can later re-open selected sessions into tmux
windows.

Subcommands:
  save    [--dir DIR]        Snapshot running sessions to a timestamped Markdown
  restore [file] [--dir DIR] fzf multi-select and relaunch into tmux windows
  list    [file] [--dir DIR] Print saved sessions without relaunching
"""

import argparse
import json
import os
import re
import sqlite3
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

HOME = Path.home()
CLAUDE_PROJECTS = HOME / ".claude" / "projects"
OPENCODE_DIR = HOME / ".local" / "share" / "opencode"
OPENCODE_DB = OPENCODE_DIR / "opencode.db"
OPENCODE_SESSIONS = OPENCODE_DIR / "storage" / "session"
DEFAULT_SAVE_DIR = Path("/Users/matt/repos/todo/ai/sessions")

JSON_BLOCK_START = "<!-- SESSIONS_JSON"
JSON_BLOCK_END = "SESSIONS_JSON -->"


# ----- Process discovery -----

def _list_processes():
    """Return list of (pid, command) for all processes."""
    out = subprocess.run(
        ["ps", "-axo", "pid=,command="],
        capture_output=True, text=True,
    ).stdout
    procs = []
    for line in out.splitlines():
        line = line.strip()
        if not line:
            continue
        pid, _, cmd = line.partition(" ")
        try:
            procs.append((int(pid), cmd.strip()))
        except ValueError:
            continue
    return procs


# Substrings that mark a process as NOT an interactive agent session.
_EXCLUDE = (
    "Claude.app",
    "Claude Helper",
    "chrome-native-host",
    "chrome_crashpad_handler",
    "--bg-spare",
    "--bg-pty-host",
    "daemon run",
    "--user-data-dir",
    "Application Support/Claude",
)


def _is_agent_command(cmd):
    """True if cmd looks like an interactive claude/opencode TUI invocation."""
    if any(x in cmd for x in _EXCLUDE):
        return False
    # Match the executable name (basename of first token).
    first = cmd.split()[0] if cmd.split() else ""
    exe = os.path.basename(first)
    if exe == "claude":
        return True
    if exe == "opencode":
        return True
    return False


def _proc_cwd(pid):
    """Return the working directory of a process via lsof, or None."""
    try:
        out = subprocess.run(
            ["lsof", "-a", "-d", "cwd", "-p", str(pid)],
            capture_output=True, text=True,
        ).stdout
    except Exception:
        return None
    for line in out.splitlines():
        if line.startswith("COMMAND"):
            continue
        # The path is everything from the first '/' onward.
        idx = line.find("/")
        if idx != -1:
            return line[idx:].strip()
    return None


# ----- Session resolution -----

def _slug_for_dir(cwd):
    """Claude project dir slug: replace '/' and '.' with '-'."""
    return re.sub(r"[/.]", "-", cwd)


# Prefixes that mark a Claude user message as a slash-command / hook wrapper
# rather than a real prompt worth using as a title.
_WRAPPER_PREFIXES = (
    "<local-command",
    "<command-",
    "<user-prompt-submit-hook",
    "Caveat: The messages below",
    "<system-reminder",
)


def _is_wrapper_text(text):
    t = text.lstrip()
    return any(t.startswith(p) for p in _WRAPPER_PREFIXES)


def _claude_meta(jsonl_path):
    """Extract (title, cwd, updated_ts) from a Claude .jsonl session file."""
    cwd = None
    summary = None
    first_user = None
    try:
        with open(jsonl_path, "r") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    d = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if not cwd and d.get("cwd"):
                    cwd = d["cwd"]
                if d.get("type") == "summary" and d.get("summary"):
                    summary = d["summary"]
                if first_user is None and d.get("type") == "user" and not d.get("isMeta"):
                    msg = d.get("message", {})
                    content = msg.get("content")
                    text = None
                    if isinstance(content, str):
                        text = content
                    elif isinstance(content, list):
                        for item in content:
                            if isinstance(item, dict) and item.get("type") == "text":
                                text = item.get("text")
                                break
                    if text and not _is_wrapper_text(text):
                        first_user = text
    except OSError:
        pass
    title = summary or (first_user or "").strip().replace("\n", " ")
    if len(title) > 90:
        title = title[:87] + "..."
    if not title:
        title = "(untitled)"
    updated = jsonl_path.stat().st_mtime if jsonl_path.exists() else time.time()
    return title, cwd, updated


def _resolve_claude(cmd, cwd):
    """Return session dict for a claude process, or None."""
    m = re.search(r"--resume\s+([0-9a-fA-F-]{36})", cmd)
    jsonl = None
    if m:
        uuid = m.group(1)
        # Find the jsonl anywhere under projects (dir known via cwd if present).
        if cwd:
            candidate = CLAUDE_PROJECTS / _slug_for_dir(cwd) / f"{uuid}.jsonl"
            if candidate.exists():
                jsonl = candidate
        if jsonl is None:
            for p in CLAUDE_PROJECTS.glob(f"*/{uuid}.jsonl"):
                jsonl = p
                break
    elif cwd:
        proj = CLAUDE_PROJECTS / _slug_for_dir(cwd)
        if proj.is_dir():
            files = sorted(
                proj.glob("*.jsonl"), key=lambda p: p.stat().st_mtime, reverse=True
            )
            if files:
                jsonl = files[0]
    if jsonl is None:
        return None
    uuid = jsonl.stem
    title, meta_cwd, updated = _claude_meta(jsonl)
    directory = cwd or meta_cwd or str(HOME)
    return {
        "tool": "claude",
        "id": uuid,
        "title": title,
        "directory": directory,
        "updated": updated,
        "command": f"claude --resume {uuid}",
    }


def _opencode_db():
    """Open the opencode SQLite DB read-only, or None if unavailable."""
    if not OPENCODE_DB.exists():
        return None
    try:
        conn = sqlite3.connect(f"file:{OPENCODE_DB}?mode=ro", uri=True, timeout=2)
        conn.row_factory = sqlite3.Row
        return conn
    except sqlite3.Error:
        return None


def _row_to_session(row):
    updated = (row["time_updated"] or 0) / 1000.0 or time.time()
    return {
        "tool": "opencode",
        "id": row["id"],
        "title": row["title"] or "(untitled)",
        "directory": row["directory"] or str(HOME),
        "updated": updated,
        "command": f"opencode -s {row['id']}",
    }


def _opencode_from_db(session_id=None, cwd=None):
    conn = _opencode_db()
    if conn is None:
        return None
    try:
        if session_id:
            cur = conn.execute(
                "SELECT id, directory, title, time_updated FROM session WHERE id=?",
                (session_id,),
            )
            row = cur.fetchone()
            if row:
                return _row_to_session(row)
        if cwd:
            cur = conn.execute(
                "SELECT id, directory, title, time_updated FROM session "
                "WHERE directory=? AND time_archived IS NULL "
                "ORDER BY time_updated DESC LIMIT 1",
                (cwd,),
            )
            row = cur.fetchone()
            if row:
                return _row_to_session(row)
    except sqlite3.Error:
        return None
    finally:
        conn.close()
    return None


def _find_opencode_json(session_id):
    for p in OPENCODE_SESSIONS.glob(f"*/{session_id}.json"):
        return p
    return None


def _opencode_from_json(session_id=None, cwd=None):
    """Legacy JSON-storage fallback for older opencode versions."""
    data = None
    if session_id:
        path = _find_opencode_json(session_id)
        if path:
            try:
                data = json.loads(path.read_text())
            except (OSError, json.JSONDecodeError):
                data = None
    if data is None and cwd:
        best = None
        best_ts = -1
        for p in OPENCODE_SESSIONS.glob("*/ses_*.json"):
            try:
                d = json.loads(p.read_text())
            except (OSError, json.JSONDecodeError):
                continue
            if d.get("directory") != cwd:
                continue
            ts = (d.get("time", {}) or {}).get("updated", 0)
            if ts > best_ts:
                best_ts = ts
                best = d
        data = best
    if data is None:
        return None
    sid = data.get("id")
    if not sid:
        return None
    updated = (data.get("time", {}) or {}).get("updated", 0) / 1000.0 or time.time()
    return {
        "tool": "opencode",
        "id": sid,
        "title": data.get("title") or "(untitled)",
        "directory": data.get("directory") or cwd or str(HOME),
        "updated": updated,
        "command": f"opencode -s {sid}",
    }


def _resolve_opencode(cmd, cwd):
    """Return session dict for an opencode process, or None.

    Prefers the SQLite DB (current opencode versions); falls back to the
    legacy JSON storage. An explicit `-s <id>` from the command line wins,
    otherwise the newest session for the process cwd is used.
    """
    m = re.search(r"-s\s+(ses_[A-Za-z0-9]+)", cmd)
    session_id = m.group(1) if m else None
    return (
        _opencode_from_db(session_id=session_id, cwd=cwd)
        or _opencode_from_json(session_id=session_id, cwd=cwd)
    )


def collect_sessions():
    """Discover all running agent sessions. Deduplicated by (tool, id)."""
    sessions = {}
    for pid, cmd in _list_processes():
        if not _is_agent_command(cmd):
            continue
        cwd = _proc_cwd(pid)
        exe = os.path.basename(cmd.split()[0])
        if exe == "claude":
            s = _resolve_claude(cmd, cwd)
        else:
            s = _resolve_opencode(cmd, cwd)
        if not s:
            continue
        s["pid"] = pid
        sessions[(s["tool"], s["id"])] = s
    return list(sessions.values())


# ----- Markdown output -----

def render_markdown(sessions):
    now = datetime.now()
    lines = [f"# Agent sessions — {now:%Y-%m-%d %H:%M}", ""]
    lines.append(f"{len(sessions)} running session(s) captured.")
    lines.append("")
    lines.append(
        "> Note: two bare `claude`/`opencode` instances in the *same* directory "
        "cannot be told apart and may resolve to the same session."
    )
    lines.append("")

    by_dir = {}
    for s in sessions:
        by_dir.setdefault(s["directory"], []).append(s)

    for directory in sorted(by_dir):
        lines.append(f"## {directory}")
        lines.append("")
        for s in sorted(by_dir[directory], key=lambda x: x["updated"], reverse=True):
            ts = datetime.fromtimestamp(s["updated"]).strftime("%H:%M")
            lines.append(f"- **[{s['tool']}]** {s['title']}  _({ts})_")
            full = f"cd {directory} && {s['command']}"
            lines.append(f"  ```")
            lines.append(f"  {full}")
            lines.append(f"  ```")
        lines.append("")

    # Machine-readable block for restore/list.
    payload = json.dumps(sessions, indent=2)
    lines.append(f"{JSON_BLOCK_START}")
    lines.append(payload)
    lines.append(f"{JSON_BLOCK_END}")
    lines.append("")
    return "\n".join(lines)


def parse_saved_json(path):
    text = Path(path).read_text()
    start = text.find(JSON_BLOCK_START)
    end = text.find(JSON_BLOCK_END)
    if start == -1 or end == -1:
        return []
    payload = text[start + len(JSON_BLOCK_START):end].strip()
    try:
        return json.loads(payload)
    except json.JSONDecodeError:
        return []


def newest_saved_file(save_dir):
    files = sorted(
        Path(save_dir).glob("*.md"), key=lambda p: p.stat().st_mtime, reverse=True
    )
    return files[0] if files else None


# ----- Subcommands -----

def cmd_save(args):
    save_dir = Path(args.dir)
    save_dir.mkdir(parents=True, exist_ok=True)
    sessions = collect_sessions()
    if not sessions:
        print("No running claude/opencode sessions found.", file=sys.stderr)
    out = render_markdown(sessions)
    stamp = datetime.now().strftime("%Y-%m-%d-%H%M")
    path = save_dir / f"{stamp}.md"
    path.write_text(out)
    print(f"Saved {len(sessions)} session(s) to {path}")
    return 0


def _resolve_file(args):
    if getattr(args, "file", None):
        return Path(args.file)
    f = newest_saved_file(args.dir)
    if not f:
        print(f"No saved session files in {args.dir}", file=sys.stderr)
        sys.exit(1)
    return f


def cmd_list(args):
    path = _resolve_file(args)
    sessions = parse_saved_json(path)
    if not sessions:
        print(f"No sessions found in {path}", file=sys.stderr)
        return 1
    print(f"# {path}")
    for s in sessions:
        print(f"[{s['tool']}] {s['title']}")
        print(f"    {s['directory']}")
        print(f"    cd {s['directory']} && {s['command']}")
    return 0


def _in_tmux():
    return bool(os.environ.get("TMUX"))


def _tmux_session_exists(name):
    r = subprocess.run(["tmux", "has-session", "-t", name], capture_output=True)
    return r.returncode == 0


def cmd_restore(args):
    path = _resolve_file(args)
    sessions = parse_saved_json(path)
    if not sessions:
        print(f"No sessions found in {path}", file=sys.stderr)
        return 1

    # Build fzf input: one line per session, tab-separated index+label.
    lines = []
    for i, s in enumerate(sessions):
        label = f"[{s['tool']}] {s['title']} — {s['directory']}"
        lines.append(f"{i}\t{label}")
    fzf_input = "\n".join(lines)

    try:
        proc = subprocess.run(
            ["fzf", "--multi", "--with-nth", "2..", "--delimiter", "\t",
             "--prompt", "restore> ", "--header", "Select sessions to reopen (TAB to multi-select)"],
            input=fzf_input, capture_output=True, text=True,
        )
    except FileNotFoundError:
        print("fzf not found on PATH.", file=sys.stderr)
        return 1
    if proc.returncode != 0 or not proc.stdout.strip():
        print("Nothing selected.", file=sys.stderr)
        return 0

    chosen = []
    for line in proc.stdout.strip().splitlines():
        idx = line.split("\t", 1)[0]
        try:
            chosen.append(sessions[int(idx)])
        except (ValueError, IndexError):
            continue

    target_session = "sessions"
    if not _in_tmux() and not _tmux_session_exists(target_session):
        subprocess.run(["tmux", "new-session", "-d", "-s", target_session])

    for s in chosen:
        window_name = f"{s['tool']}:{os.path.basename(s['directory']) or 'root'}"
        run_cmd = f"cd {subprocess.list2cmdline([s['directory']])} && {s['command']}"
        new_window = ["tmux", "new-window", "-c", s["directory"], "-n", window_name]
        if not _in_tmux():
            new_window += ["-t", target_session]
        new_window.append(run_cmd)
        subprocess.run(new_window)
        print(f"Reopened [{s['tool']}] {s['title']}")

    if not _in_tmux():
        print(f"\nSessions launched in tmux session '{target_session}'.")
        print(f"Attach with: tmux attach -t {target_session}")
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd")

    p_save = sub.add_parser("save", help="Snapshot running sessions to Markdown")
    p_save.add_argument("--dir", default=str(DEFAULT_SAVE_DIR))
    p_save.set_defaults(func=cmd_save)

    p_restore = sub.add_parser("restore", help="Reopen selected sessions in tmux")
    p_restore.add_argument("file", nargs="?")
    p_restore.add_argument("--dir", default=str(DEFAULT_SAVE_DIR))
    p_restore.set_defaults(func=cmd_restore)

    p_list = sub.add_parser("list", help="Print saved sessions")
    p_list.add_argument("file", nargs="?")
    p_list.add_argument("--dir", default=str(DEFAULT_SAVE_DIR))
    p_list.set_defaults(func=cmd_list)

    args = parser.parse_args()
    if not getattr(args, "cmd", None):
        # Default to save.
        args.dir = str(DEFAULT_SAVE_DIR)
        return cmd_save(args)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
