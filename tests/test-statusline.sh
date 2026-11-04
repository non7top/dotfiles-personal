#!/usr/bin/env bash
# Unit tests for Antigravity and Claude statusline and title scripts.
# Runs inside the disposable test container (make test-statusline).
set -uo pipefail

REPO=${REPO:-$(cd "$(dirname "$0")/.." && pwd)}
pass=0 fail=0
ok()  { echo "  ok: $1"; pass=$((pass + 1)); }
bad() { echo "  FAIL: $1"; fail=$((fail + 1)); }

SCRATCH=$(mktemp -d)
trap 'rm -rf "$SCRATCH"' EXIT

# Helper to strip ANSI escape codes
strip_ansi() {
    sed -E 's/\x1b\[[0-9;]*m//g'
}

echo "== setup test git repo"
TEST_REPO="$SCRATCH/my-project"
mkdir -p "$TEST_REPO/subdir/nested"
git -C "$TEST_REPO" init -q -b main
git -C "$TEST_REPO" config user.email test@example.com
git -C "$TEST_REPO" config user.name test
git -C "$TEST_REPO" config commit.gpgSign false
echo "hello" > "$TEST_REPO/file.txt"
git -C "$TEST_REPO" add file.txt
git -C "$TEST_REPO" commit -q -m "initial commit"
echo "change" >> "$TEST_REPO/file.txt"

echo "== Antigravity CLI title script"
TITLE_CMD="$REPO/gemini/_title-command.sh"

out=$(echo "{\"agent_state\": \"idle\", \"workspace\": {\"project_dir\": \"$TEST_REPO\"}}" | bash "$TITLE_CMD")
if [ "$out" = "💤 my-project - idle" ]; then
    ok "title: idle state formatting"
else
    bad "title: idle state expected '💤 my-project - idle', got '$out'"
fi

out=$(echo "{\"agent_state\": \"thinking\", \"workspace\": {\"project_dir\": \"$TEST_REPO\"}}" | bash "$TITLE_CMD")
if [ "$out" = "🤔 my-project - thinking" ]; then
    ok "title: thinking state formatting"
else
    bad "title: thinking state expected '🤔 my-project - thinking', got '$out'"
fi

out=$(echo "{\"agent_state\": \"working\", \"workspace\": {\"project_dir\": \"$TEST_REPO\"}}" | bash "$TITLE_CMD")
if [ "$out" = "⚙️ my-project - working" ]; then
    ok "title: working state formatting"
else
    bad "title: working state expected '⚙️ my-project - working', got '$out'"
fi

out=$(echo "{\"agent_state\": \"tool_use\", \"workspace\": {\"project_dir\": \"$TEST_REPO\"}}" | bash "$TITLE_CMD")
if [ "$out" = "⚙️ my-project - tool_use" ]; then
    ok "title: tool_use state formatting"
else
    bad "title: tool_use state expected '⚙️ my-project - tool_use', got '$out'"
fi

out=$(echo "{\"agent_state\": \"error\", \"workspace\": {\"project_dir\": \"$TEST_REPO\"}}" | bash "$TITLE_CMD")
if [ "$out" = "❌ my-project - error" ]; then
    ok "title: error state formatting"
else
    bad "title: error state expected '❌ my-project - error', got '$out'"
fi

out=$(echo "{\"agent_state\": \"custom\", \"workspace\": {\"project_dir\": \"$TEST_REPO\"}}" | bash "$TITLE_CMD")
if [ "$out" = "🛰️ my-project - custom" ]; then
    ok "title: fallback icon formatting"
else
    bad "title: fallback icon expected '🛰️ my-project - custom', got '$out'"
fi

out=$(echo "{\"agent_state\": \"idle\", \"cwd\": \"$TEST_REPO/subdir/nested\"}" | bash "$TITLE_CMD")
if [ "$out" = "💤 my-project - idle" ]; then
    ok "title: resolves repo root basename from nested directory"
else
    bad "title: nested dir expected '💤 my-project - idle', got '$out'"
fi

NON_GIT="$SCRATCH/non-git-folder"
mkdir -p "$NON_GIT"
out=$(echo "{\"agent_state\": \"idle\", \"cwd\": \"$NON_GIT\"}" | bash "$TITLE_CMD")
if [ "$out" = "💤 non-git-folder - idle" ]; then
    ok "title: non-git directory uses folder basename"
else
    bad "title: non-git expected '💤 non-git-folder - idle', got '$out'"
fi

echo "== statusline common git segment"
source "$REPO/_statusline-common.sh"

out=$(sl_git_segment "$TEST_REPO" "main" | strip_ansi)
if [[ "$out" == *"my-project [main]"* ]]; then
    ok "git_segment: root directory name and branch"
else
    bad "git_segment: root expected 'my-project [main]', got '$out'"
fi

out=$(sl_git_segment "$TEST_REPO/subdir/nested" "main" | strip_ansi)
if [[ "$out" == *"my-project [main]"* ]]; then
    ok "git_segment: resolves repo root basename from subdirectory"
else
    bad "git_segment: subfolder expected 'my-project [main]', got '$out'"
fi

out=$(sl_git_segment "$TEST_REPO" "main" "auto" | strip_ansi)
if [[ "$out" == *"my-project [main]"*"(auto)"* ]]; then
    ok "git_segment: mode displayed in parens"
else
    bad "git_segment: mode expected '(auto)', got '$out'"
fi

out=$(sl_git_segment "$NON_GIT" "" | strip_ansi)
if [ "$out" = "not in git repo" ]; then
    ok "git_segment: non-git directory"
else
    bad "git_segment: non-git expected 'not in git repo', got '$out'"
fi

out=$(sl_git_segment "$NON_GIT" "" "plan" | strip_ansi)
if [ "$out" = "not in git repo (plan)" ]; then
    ok "git_segment: non-git directory with mode"
else
    bad "git_segment: non-git with mode expected 'not in git repo (plan)', got '$out'"
fi

echo "== Antigravity CLI statusline command"
STATUSLINE_CMD="$REPO/gemini/_statusline-command.sh"

payload=$(cat <<EOF
{
  "cwd": "$TEST_REPO/subdir",
  "terminal_width": 200,
  "permission_mode": "auto",
  "context_window": {"used_percentage": 10},
  "quota": {
    "gemini-5h": {"remaining_fraction": 0.8, "reset_in_seconds": 3600},
    "gemini-weekly": {"remaining_fraction": 0.5, "reset_in_seconds": 86400},
    "gemini-argon-wtu-weekly": {"remaining_fraction": 0.3, "reset_in_seconds": 172800},
    "3p-5h": {"remaining_fraction": 0.9, "reset_in_seconds": 3600},
    "3p-weekly": {"remaining_fraction": 0.4, "reset_in_seconds": 86400}
  }
}
EOF
)

out=$(echo "$payload" | bash "$STATUSLINE_CMD" | strip_ansi)
if [[ "$out" == *"my-project [main]"*"(auto)"* ]]; then
    ok "statusline: displays repo root and permission mode"
else
    bad "statusline: expected repo root and (auto), got '$out'"
fi

if [[ "$out" == *"Ar ["* ]]; then
    ok "statusline: displays Argon quota segment when present"
else
    bad "statusline: expected Argon segment 'Ar [', got '$out'"
fi

if [[ "$out" == *"3p["* ]]; then
    ok "statusline: displays compact 3p quota segment"
else
    bad "statusline: expected compact 3p segment, got '$out'"
fi

cycle_payload="{\"cwd\": \"$TEST_REPO/subdir\", \"terminal_width\": 200, \"cycle_mode\": \"accept-edits\"}"
out=$(echo "$cycle_payload" | bash "$STATUSLINE_CMD" | strip_ansi)
if [[ "$out" == *"my-project [main]"*"(accept-edits)"* ]]; then
    ok "statusline: displays cycle_mode (accept-edits)"
else
    bad "statusline: expected (accept-edits), got '$out'"
fi

echo
echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
