#!/usr/bin/env python3
"""
Pre-tool-use hook: ask before high-blast-radius `gh` invocations.

Everything is allowed except commands matching a rule in DEFAULT_RULES (plus
any machine-local additions). A match returns permissionDecision "ask", so the
command goes to a native approval prompt instead of being refused.

A rule is a space-separated subcommand prefix, optionally followed by flags
that must also be present: "release create", "pr merge --admin". `gh api` is
matched as "api read" (GET) or "api write" (any other method, including the
implied POST of -f/-F), so a machine can deny "api write" or all of "api".

Machine-local overrides live in ~/.config/claude/gh-guard.json (untracked):

    {"deny": ["pr create", "pr comment"], "allow": ["release create"]}

"deny" adds rules; "allow" removes default rules (exact string match).
"""
import json
import os
import shlex
import sys

DEFAULT_RULES = [
    # Repo-level destructive.
    "repo delete",
    "repo archive",
    "repo unarchive",
    "repo rename",
    "repo edit",
    "repo deploy-key add",
    "repo deploy-key delete",
    # Releases, secrets and variables.
    "release create",
    "release delete",
    "release delete-asset",
    "release edit",
    "release upload",
    "secret set",
    "secret delete",
    "variable set",
    "variable delete",
    # Bypasses branch protection and required checks.
    "pr merge --admin",
    # Raw API writes can reach any of the above.
    "api write",
]

CONFIG_PATH = os.path.expanduser("~/.config/claude/gh-guard.json")

WRITE_METHODS = {"POST", "PUT", "PATCH", "DELETE"}

# `gh api` defaults to GET but switches to POST as soon as a parameter is
# attached, so these are writes even with no -X flag.
PARAMETER_FLAGS = ("-f", "--raw-field", "-F", "--field", "--input")

# Flags that take a value, so the value is not mistaken for a subcommand.
VALUE_FLAGS = ("-R", "--repo", "--hostname")

# shlex's punctuation_chars set; a token made only of these is a shell operator.
PUNCTUATION = set("();<>|&")


def ask(reason):
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "ask",
            "permissionDecisionReason": f"[gh-guard] {reason}",
        }
    }))
    sys.exit(0)


def load_rules():
    rules = [" ".join(r.split()) for r in DEFAULT_RULES]
    try:
        with open(CONFIG_PATH) as f:
            config = json.load(f)
    except FileNotFoundError:
        return rules
    except (OSError, ValueError) as exc:
        # A broken config must not silently loosen a machine meant to be strict.
        ask(f"cannot read {CONFIG_PATH} ({exc}); asking for every gh command")
    allow = {" ".join(r.split()) for r in config.get("allow", [])}
    rules = [r for r in rules if r not in allow]
    rules += [" ".join(r.split()) for r in config.get("deny", [])]
    return rules


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
        if arg.startswith(("--raw-field=", "--field=", "--input=")):
            return True
        if not arg.startswith("--") and len(arg) > 2 and arg[:2] in ("-f", "-F"):
            return True
    return False


def positionals(args):
    result = []
    skip = False
    for arg in args:
        if skip:
            skip = False
        elif arg in VALUE_FLAGS:
            skip = True
        elif not arg.startswith("-"):
            result.append(arg)
    return result


def words(args):
    """The subcommand words a rule is matched against."""
    positional = positionals(args)
    if positional[:1] == ["api"]:
        write = has_write_method(args) or has_parameter_flag(args)
        return ["api", "write" if write else "read"]
    return positional


def matches(rule, args, command_words):
    parts = rule.split()
    prefix = [p for p in parts if not p.startswith("-")]
    flags = [p for p in parts if p.startswith("-")]
    if command_words[: len(prefix)] != prefix:
        return False
    return all(any(a == f or a.startswith(f + "=") for a in args) for f in flags)


def check_gh_command(tokens, rules):
    args = tokens[1:]
    command_words = words(args)
    for rule in rules:
        if matches(rule, args, command_words):
            ask(f"`{' '.join(tokens)}` matches guarded rule `{rule}`")


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
    if "gh" not in command:
        sys.exit(0)
    rules = load_rules()
    try:
        tokens = tokenize(command)
    except ValueError:
        # Unbalanced quotes, so we cannot reason about the command.
        if "gh" in command.split():
            ask(f"unparseable command containing `gh`: {command}")
        sys.exit(0)
    for tokens in map(strip_env_prefix, commands(tokens)):
        if tokens and os.path.basename(tokens[0]) == "gh":
            check_gh_command(tokens, rules)
    sys.exit(0)


if __name__ == "__main__":
    main()
