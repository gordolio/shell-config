#!/usr/bin/env python3
"""
Pre-tool-use hook: deny-by-default for `gh` invocations.

The read-only subcommands in ALLOWED_SUBCOMMANDS are allowed, plus narrowly
shaped writes in SCOPED_WRITES (draft PR create, PR attachments/body/base,
PR comments, stack link). `--help`/`-h` is allowed on any subcommand, because gh
prints help and exits without running it. Everything else (including any `gh`
subcommand we don't know about yet) is blocked. `gh api` is allowed only when
no write-method flag is present.

Every command in a line is checked: commands split on shell operators and on
newlines, and heredoc bodies are dropped before tokenizing (their text is data,
and an apostrophe in it would otherwise make the whole line unparseable).
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
    ("repo", "list"),
    ("release", "view"),
    ("release", "list"),
    ("run", "view"),
    ("run", "list"),
    ("workflow", "view"),
    ("workflow", "list"),
    ("search",),
    ("version",),
    ("extension", "list"),
    ("stack", "view"),
]

# Scoped GitHub writes. The hook only narrows their shape; the agent must still
# confirm with Gordon first (see "GitHub writes" in ~/.config/opencode/AGENTS.md).
REPO_FLAGS = ("-R", "--repo")
STACK_LINK_ARG = re.compile(r"\d+|https://github\.com/[\w.-]+/[\w.-]+/pull/\d+")


def only_flags(args, allowed):
    return all(
        not a.startswith("-") or a in allowed or a.split("=", 1)[0] in allowed
        for a in args
    )


def check_scoped_write(positional, args):
    if positional[:2] == ["pr", "create"]:
        if "--draft" not in args and "-d" not in args:
            return "`gh pr create` must use --draft"
        return None
    if positional[:2] == ["pr", "edit"]:
        # --base retargets a PR within a stack (split-pr / rebase-pr-stack).
        edit_flags = ("--attach", "--body-file", "--base", "-B")
        if not any(a.split("=", 1)[0] in edit_flags for a in args):
            return "`gh pr edit` is only allowed with --attach, --body-file or --base"
        if not only_flags(args, edit_flags + REPO_FLAGS):
            return "`gh pr edit` may only use --attach, --body-file, --base (and --repo)"
        return None
    if positional[:2] == ["pr", "comment"]:
        if "--delete-last" in args:
            return "`gh pr comment --delete-last` is not allowed"
        return None
    if positional[:2] == ["stack", "link"]:
        # Branch arguments are pushed and get PRs auto-created, and --open
        # marks PRs ready for review, so only existing PRs (numbers or URLs).
        if any(a.startswith("-") for a in args):
            return "`gh stack link` takes no flags here"
        if not all(STACK_LINK_ARG.fullmatch(a) for a in positional[2:]):
            return "`gh stack link` only accepts PR numbers or PR URLs"
        return None
    return "not a scoped write"


SCOPED_WRITES = [("pr", "create"), ("pr", "edit"), ("pr", "comment"), ("stack", "link")]

WRITE_METHODS = {"POST", "PUT", "PATCH", "DELETE"}

# `gh api` defaults to GET but switches to POST as soon as a parameter is
# attached, so these are writes even with no -X flag.
PARAMETER_FLAGS = ("-f", "--raw-field", "-F", "--field")

# A token made only of these is a shell operator. Newline is one too: it ends a
# command just like `;`, so it must not be treated as plain whitespace.
PUNCTUATION_CHARS = "();<>|&\n"
PUNCTUATION = set(PUNCTUATION_CHARS)

# `<<EOF`, `<<-EOF`, `<<'EOF'`, `<< "EOF"` (not the `<<<` here-string).
HEREDOC = re.compile(r"(?<!<)<<(?!<)-?[ \t]*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\1")


def block(reason):
    sys.stderr.write(f"[gh-allowlist] BLOCKED: {reason}\n")
    sys.stderr.write(
        "Only read-only gh commands plus confirmed `pr create --draft`, "
        "`pr edit --attach/--body-file/--base`, `pr comment` and `stack link` are allowed. "
        "Draft anything else in chat for Gordon to run himself.\n"
    )
    sys.exit(2)


def strip_heredocs(command):
    """Drop heredoc bodies, keeping the `<<DELIM` operator line itself."""
    lines = command.split("\n")
    kept = []
    pending = []  # delimiters whose bodies start on the next line, in order
    for line in lines:
        if pending:
            if line.lstrip("\t") == pending[0]:
                pending.pop(0)
            continue
        kept.append(line)
        pending.extend(m.group(2) for m in HEREDOC.finditer(line))
    return "\n".join(kept)


def tokenize(command):
    """Split a command line into tokens, honouring quotes and grouping operators."""
    lexer = shlex.shlex(command, posix=True, punctuation_chars=PUNCTUATION_CHARS)
    lexer.whitespace = " \t\r"
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
    if "--help" in args or "-h" in args:
        return
    positional = [a for a in args if not a.startswith("-")]
    if not positional:
        if args and all(a in ("--version", "-v") for a in args):
            return
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
    if tuple(positional[:2]) in SCOPED_WRITES:
        reason = check_scoped_write(positional, args)
        if reason:
            block(f"{reason}: {' '.join(tokens)}")
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
        tokens = tokenize(strip_heredocs(command))
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
