#!/usr/bin/env python3
"""
Pre-tool-use hook: agents may push a NEW branch, and nothing else.

Allowed shape, and only this: `git push [-u|--set-upstream] origin <branch>`
where <branch> exists locally, is not a protected name, and does not exist on
origin yet (checked live with `git ls-remote`). Every other `git push` is
blocked: force, delete, refspecs, tags, --all/--mirror, bare `git push`, and
pushes to branches that already exist on the remote. The agent must still
confirm with Gordon first (see "Git Boundaries" in ~/.config/opencode/AGENTS.md).

Symlinked to ~/.claude/hooks/ by `ls-tools --fix` and registered under
hooks.PreToolUse[matcher=Bash] in ~/.claude/settings.json.
"""
import json
import os
import re
import subprocess
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
from importlib import import_module  # noqa: E402

gh = import_module("gh-allowlist")

PROTECTED = re.compile(r"(dev|develop|main|master|staging|production|prod|release[/-].*|hotfix[/-].*)")
UPSTREAM_FLAGS = {"-u", "--set-upstream"}
GIT_GLOBAL_WITH_VALUE = {"-C", "-c", "--git-dir", "--work-tree", "--namespace"}


def block(reason):
    sys.stderr.write(f"[git-push-allowlist] BLOCKED: {reason}\n")
    sys.stderr.write(
        "Agents may only run `git push -u origin <branch>` for a branch that does "
        "not exist on origin yet. Print anything else for Gordon to run.\n"
    )
    sys.exit(2)


def split_git(tokens):
    directory = None
    index = 1
    while index < len(tokens) and tokens[index].startswith("-"):
        flag = tokens[index]
        if flag in GIT_GLOBAL_WITH_VALUE:
            if flag == "-C" and index + 1 < len(tokens):
                directory = tokens[index + 1]
            index += 2
        else:
            index += 1
    return directory, tokens[index:]


def git(directory, *args):
    return subprocess.run(
        ["git", "-C", directory, *args], capture_output=True, text=True, timeout=20
    )


def check_push(args, directory):
    positional = [a for a in args if not a.startswith("-")]
    flags = [a for a in args if a.startswith("-")]
    if any(f not in UPSTREAM_FLAGS for f in flags):
        block(f"flags not allowed: {' '.join(f for f in flags if f not in UPSTREAM_FLAGS)}")
    if len(positional) != 2 or positional[0] != "origin":
        block("use exactly `git push -u origin <branch>`")
    branch = positional[1]
    if not re.fullmatch(r"[A-Za-z0-9._/-]+", branch) or branch.startswith("-"):
        block(f"not a plain branch name (no refspecs): {branch}")
    if PROTECTED.fullmatch(branch):
        block(f"`{branch}` is a protected branch")
    if not os.path.isdir(directory) or git(directory, "rev-parse", "--git-dir").returncode:
        block(f"cannot resolve the repository for this push ({directory})")
    if git(directory, "show-ref", "--verify", "--quiet", f"refs/heads/{branch}").returncode:
        block(f"no local branch `{branch}` in {directory}")
    remote = git(directory, "ls-remote", "--exit-code", "--heads", "origin", f"refs/heads/{branch}")
    if remote.returncode == 0:
        block(f"`{branch}` already exists on origin; only new branches may be pushed")
    if remote.returncode != 2:
        block(f"could not check origin for `{branch}`: {remote.stderr.strip()}")


def main():
    try:
        payload = json.load(sys.stdin)
    except Exception:
        sys.exit(0)
    if payload.get("tool_name") != "Bash":
        sys.exit(0)
    tool_input = payload.get("tool_input", {})
    command = tool_input.get("command", "")
    if not re.search(r"\bpush\b", command):
        sys.exit(0)
    try:
        tokens = gh.tokenize(gh.strip_heredocs(command))
    except ValueError:
        block(f"unparseable command containing `push`: {command}")
    base = tool_input.get("workdir") or payload.get("cwd") or os.getcwd()
    directory = base
    for tokens in map(gh.strip_env_prefix, gh.commands(tokens)):
        if len(tokens) >= 2 and tokens[0] == "cd":
            directory = os.path.join(directory, os.path.expanduser(tokens[1]))
            continue
        if not tokens or tokens[0] != "git":
            continue
        override, args = split_git(tokens)
        if args and args[0] == "push":
            target = os.path.join(directory, os.path.expanduser(override)) if override else directory
            check_push(args[1:], os.path.normpath(target))
    sys.exit(0)


if __name__ == "__main__":
    main()
