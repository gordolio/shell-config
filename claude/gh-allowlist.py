#!/usr/bin/env python3
"""
Pre-tool-use hook: deny-by-default for `gh` invocations.

Only the read-only subcommands listed in ALLOWED_SUBCOMMANDS are allowed.
Everything else (including any `gh` subcommand we don't know about yet) is
blocked. `gh api` is allowed only when no write-method flag is present.
"""
import json
import re
import shlex
import sys

ALLOWED_SUBCOMMANDS = [
    ("auth", "status"),
    ("pr", "view"),
    ("pr", "list"),
    ("pr", "diff"),
    ("pr", "checks"),
    ("pr", "status"),
    ("issue", "view"),
    ("issue", "list"),
    ("issue", "status"),
    ("repo", "view"),
    ("release", "view"),
    ("release", "list"),
    ("run", "view"),
    ("run", "list"),
    ("workflow", "view"),
    ("workflow", "list"),
    ("search",),
]

WRITE_METHOD_RE = re.compile(
    r"(^|\s)(-X|--method)(\s+|=)(POST|PUT|PATCH|DELETE)\b", re.IGNORECASE
)


def block(reason):
    sys.stderr.write(f"[gh-allowlist] BLOCKED: {reason}\n")
    sys.stderr.write(
        "Gordon's standing rule: Claude never writes to GitHub. "
        "Draft the action in chat for Gordon to run himself.\n"
    )
    sys.exit(2)


def check_gh_segment(tokens):
    args = tokens[1:]
    positional = [a for a in args if not a.startswith("-")]
    if not positional:
        block("bare `gh` invocation")
    if positional[0] == "api":
        if WRITE_METHOD_RE.search(" ".join(args)):
            block(f"`gh api` with write method: {' '.join(tokens)}")
        return
    for entry in ALLOWED_SUBCOMMANDS:
        if tuple(positional[: len(entry)]) == entry:
            return
    block(f"`{' '.join(tokens[:3])}` not on read-only allowlist")


def main():
    try:
        payload = json.load(sys.stdin)
    except Exception:
        sys.exit(0)
    if payload.get("tool_name") != "Bash":
        sys.exit(0)
    command = payload.get("tool_input", {}).get("command", "")
    segments = re.split(r"&&|\|\||;|\|", command)
    for seg in segments:
        seg = seg.strip()
        if not (seg == "gh" or seg.startswith("gh ") or seg.startswith("gh\t")):
            continue
        try:
            tokens = shlex.split(seg)
        except ValueError:
            block(f"unparseable gh segment: {seg}")
        check_gh_segment(tokens)
    sys.exit(0)


if __name__ == "__main__":
    main()
