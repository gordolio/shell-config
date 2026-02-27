#!/bin/bash
#
# capture-claude-headers.sh — Capture HTTP headers sent by Claude Code
# Uses mitmdump to intercept a single Claude API request and save the headers.
#
# Usage: ./capture-claude-headers.sh [version]
#   version defaults to reading from the claude symlink

set -euo pipefail

# Check dependencies
missing=()
for cmd in mitmdump jq python3 claude; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
done
if [ ${#missing[@]} -gt 0 ]; then
    echo "Missing dependencies: ${missing[*]}" >&2
    exit 1
fi

HEADER_DIR="$HOME/.claw-header-detect"
ADDON_SCRIPT="$HEADER_DIR/header-dump.py"
CAPTURE_TMP="$HEADER_DIR/.capture-tmp.json"
LOCKFILE="$HEADER_DIR/.capture.lock"

mkdir -p "$HEADER_DIR"

# Prevent concurrent captures (mkdir is atomic)
if ! mkdir "$LOCKFILE" 2>/dev/null; then
    lock_age=$(( $(date +%s) - $(stat -f %m "$LOCKFILE" 2>/dev/null || echo 0) ))
    if [ "$lock_age" -lt 120 ]; then
        exit 0  # another capture is running
    fi
    rm -rf "$LOCKFILE"  # stale lock
    mkdir "$LOCKFILE" 2>/dev/null || exit 0
fi
trap 'rm -rf "$LOCKFILE"; rm -f "$CAPTURE_TMP"' EXIT

# Determine version
if [ -n "${1:-}" ]; then
    version="$1"
else
    version=$(readlink "$HOME/.local/bin/claude" 2>/dev/null | xargs basename 2>/dev/null || true)
    if [ -z "$version" ]; then
        version=$(claude --version 2>/dev/null | head -1 | awk '{print $1}')
    fi
fi

if [ -z "$version" ]; then
    echo "Could not determine claude version" >&2
    exit 1
fi

# Write the mitmdump addon script
cat > "$ADDON_SCRIPT" << 'PYTHON'
import json
import os

CAPTURE_DIR = os.path.expanduser("~/.claw-header-detect")
CAPTURE_TMP = os.path.join(CAPTURE_DIR, ".capture-tmp.json")

# Collect all requests; prefer messages endpoint
captured = []

def request(flow):
    if "anthropic" in flow.request.host or "claude" in flow.request.host:
        # Strip Authorization header to avoid storing tokens
        headers = dict(flow.request.headers)
        headers.pop("Authorization", None)
        headers.pop("authorization", None)
        entry = {
            "url": flow.request.url,
            "method": flow.request.method,
            "headers": headers
        }
        captured.append(entry)
        # Write all captured requests, most recent last
        with open(CAPTURE_TMP, "w") as f:
            json.dump(captured, f, indent=2)
PYTHON

# Find a free port
find_free_port() {
    python3 -c 'import socket; s=socket.socket(); s.bind(("",0)); print(s.getsockname()[1]); s.close()'
}

PORT=$(find_free_port)

# Ensure mitmproxy CA exists (first run generates it)
if [ ! -f "$HOME/.mitmproxy/mitmproxy-ca-cert.pem" ]; then
    echo "Generating mitmproxy CA certificates (first run)..."
    mitmdump -p 0 -q &
    INIT_PID=$!
    sleep 2
    kill "$INIT_PID" 2>/dev/null || true
    wait "$INIT_PID" 2>/dev/null || true
    if [ ! -f "$HOME/.mitmproxy/mitmproxy-ca-cert.pem" ]; then
        echo "Failed to generate mitmproxy CA cert" >&2
        exit 1
    fi
fi

# Start mitmdump in background
rm -f "$CAPTURE_TMP"
mitmdump -p "$PORT" -s "$ADDON_SCRIPT" -q &
MITM_PID=$!

# Give mitmdump a moment to start
sleep 1

# Verify mitmdump is running
if ! kill -0 "$MITM_PID" 2>/dev/null; then
    echo "mitmdump failed to start" >&2
    exit 1
fi

# Run claude through the proxy
echo "hi" | HTTPS_PROXY="http://127.0.0.1:$PORT" \
    NODE_EXTRA_CA_CERTS="$HOME/.mitmproxy/mitmproxy-ca-cert.pem" \
    CLAUDECODE="" \
    claude -p 2>/dev/null || true

# Give mitmdump a moment to flush
sleep 1

# Kill mitmdump
kill "$MITM_PID" 2>/dev/null || true
wait "$MITM_PID" 2>/dev/null || true

# Check if we captured anything
if [ ! -f "$CAPTURE_TMP" ]; then
    echo "No headers captured" >&2
    exit 1
fi

# Pick the best request: prefer /messages endpoint, fall back to first anthropic request
# The capture file is a JSON array of all intercepted requests
PREV_HEADERS="$HEADER_DIR/latest-headers.json"
NEW_HEADERS="$HEADER_DIR/headers-${version}.json"

jq '
    (map(select(.url | test("/v1/messages"))) | first) //
    (map(select(.url | test("anthropic"))) | first) //
    first
' "$CAPTURE_TMP" > "$NEW_HEADERS" 2>/dev/null

if [ ! -s "$NEW_HEADERS" ] || [ "$(cat "$NEW_HEADERS")" = "null" ]; then
    rm -f "$NEW_HEADERS"
    echo "No relevant requests captured" >&2
    exit 1
fi

cp "$CAPTURE_TMP" "$HEADER_DIR/all-requests-${version}.json"

# Headers to exclude from diff (volatile per-request values)
DIFF_FILTER='del(.["Content-Length", "X-Stainless-Retry-Count"])'

# Diff against previous if it exists
if [ -f "$PREV_HEADERS" ]; then
    diff_output=$(diff <(jq -S ".headers | $DIFF_FILTER" "$PREV_HEADERS" 2>/dev/null) \
                       <(jq -S ".headers | $DIFF_FILTER" "$NEW_HEADERS" 2>/dev/null) || true)
    if [ -n "$diff_output" ]; then
        notice="$HEADER_DIR/changed-notice"
        {
            echo "Headers changed: $version (captured $(date '+%Y-%m-%d %H:%M'))"
            echo ""
            echo "$diff_output"
        } > "$notice"
        echo "Headers changed! See $notice"
    else
        echo "Headers unchanged for $version"
    fi
else
    echo "First capture for $version"
fi

# Update latest-headers.json and last-version
cp "$NEW_HEADERS" "$PREV_HEADERS"
echo "$version" > "$HEADER_DIR/last-version"

# Extract anthropic-beta header for use by statusline
beta_value=$(jq -r '.headers["anthropic-beta"] // empty' "$NEW_HEADERS" 2>/dev/null)
if [ -n "$beta_value" ]; then
    echo "$beta_value" > "$HEADER_DIR/anthropic-beta"
    rm -f "$HEADER_DIR/beta-missing"
else
    # anthropic-beta header is gone entirely — flag for manual review
    echo "anthropic-beta header missing in $version (captured $(date '+%Y-%m-%d %H:%M'))" > "$HEADER_DIR/beta-missing"
    rm -f "$HEADER_DIR/anthropic-beta"
fi

echo "Headers saved to $NEW_HEADERS"
