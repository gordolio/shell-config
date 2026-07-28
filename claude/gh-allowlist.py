#!/usr/bin/env python3
"""
Pre-tool-use hook: deny-by-default for `gh` invocations.

Only the read-only subcommands listed in ALLOWED_SUBCOMMANDS are allowed.
Everything else (including any `gh` subcommand we don't know about yet) is
blocked. `gh api` is allowed only when no write-method flag is present.
"""
import json
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
    ("repo", "list"),
    ("release", "view"),
    ("release", "list"),
    ("run", "view"),
    ("run", "list"),
    ("workflow", "view"),
    ("workflow", "list"),
    ("search",),
]

WRITE_METHODS = {"POST", "PUT", "PATCH", "DELETE"}

# `gh api` defaults to GET but switches to POST as soon as a parameter is
# attached, so these are writes even with no -X flag.
PARAMETER_FLAGS = ("-f", "--raw-field", "-F", "--field")

# shlex's punctuation_chars set; a token made only of these is a shell operator.
PUNCTUATION = set("();<>|&")


def block(reason):
    sys.stderr.write(f"[gh-allowlist] BLOCKED: {reason}\n")
    sys.stderr.write(
        "Gordon's standing rule: Claude never writes to GitHub. "
        "Draft the action in chat for Gordon to run himself.\n"
    )
    sys.exit(2)


def tokenize(command):
    """Split a command line into tokens, honouring quotes and grouping operators."""
    lexer = shlex.shlex(command, posix=True, punctuation_chars=True)
    lexer.whitespace_split = True
    return list(lexer)


def is_operator(token):
    return bool(token) and all(char in PUNCTUATION for char in token)


def commands(tokens):
    """Yield the token list of each command in the pipeline."""
    current = []
    for token in tokens:
        if is_operator(token):
            yield current
            current = []
        else:
            current.append(token)
    yield current


def has_write_method(args):
    for index, arg in enumerate(args):
        if arg in ("-X", "--method"):
            value = args[index + 1] if index + 1 < len(args) else None
        elif arg.startswith("--method="):
            value = arg[len("--method=") :]
        elif arg.startswith("-X") and len(arg) > 2:
            value = arg[2:].lstrip("=")
        else:
            continue
        if value and value.strip().upper() in WRITE_METHODS:
            return True
    return False


def has_parameter_flag(args):
    for arg in args:
        if arg in PARAMETER_FLAGS:
            return True
        if arg.startswith("--raw-field=") or arg.startswith("--field="):
            return True
        if not arg.startswith("--") and len(arg) > 2 and arg[:2] in ("-f", "-F"):
            return True
    return False


def check_gh_command(tokens):
    args = tokens[1:]
    positional = [a for a in args if not a.startswith("-")]
    if not positional:
        block("bare `gh` invocation")
    if positional[0] == "api":
        if has_write_method(args):
            block(f"`gh api` with write method: {' '.join(tokens)}")
        if has_parameter_flag(args):
            block(f"`gh api` with parameters (implies POST): {' '.join(tokens)}")
        return
    for entry in ALLOWED_SUBCOMMANDS:
        if tuple(positional[: len(entry)]) == entry:
            return
    block(f"`{' '.join(tokens[:3])}` not on read-only allowlist")


def strip_env_prefix(tokens):
    while tokens and not tokens[0].startswith("-") and "=" in tokens[0]:
        tokens = tokens[1:]
    return tokens


def main():
    try:
        payload = json.load(sys.stdin)
    except Exception:
        sys.exit(0)
    if payload.get("tool_name") != "Bash":
        sys.exit(0)
    command = payload.get("tool_input", {}).get("command", "")
    try:
        tokens = tokenize(command)
    except ValueError:
        # Unbalanced quotes, so we cannot reason about the command. Stay out of
        # the way unless a `gh` invocation might be hiding in it.
        if "gh" in command.split():
            block(f"unparseable command containing `gh`: {command}")
        sys.exit(0)
    for tokens in map(strip_env_prefix, commands(tokens)):
        if tokens and tokens[0] == "gh":
            check_gh_command(tokens)
    sys.exit(0)


if __name__ == "__main__":
    main()
