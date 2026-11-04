#!/usr/bin/env bash
# Antigravity CLI window title: icon + project name + status.
#
# Payload/config shape (title.command in ~/.gemini/antigravity-cli/settings.json,
# JSON on stdin with .agent_state / .workspace.project_dir / .workspace.current_dir / .cwd).
#
# Must NOT emit ANSI/escape sequences here -- the CLI does the actual
# window-title injection itself, unlike the statusline command.

input=$(cat)

state=$(echo "$input" | jq -r '.agent_state // "unknown"')
workspace=$(echo "$input" | jq -r '.workspace.project_dir // .workspace.current_dir // .cwd // ""')
repo_root=$(git --no-optional-locks -C "$workspace" rev-parse --show-toplevel 2>/dev/null)
if [ -n "$repo_root" ]; then
    project=$(basename "$repo_root")
else
    project=$(basename "$workspace")
fi
[ -z "$project" ] && project="unknown"

case "$state" in
    idle)            icon="💤" ;;
    thinking)        icon="🤔" ;;
    working|running|tool_use) icon="🛰️" ;;
    error)           icon="❌" ;;
    *)               icon="🛰️" ;;
esac

printf "%s %s - %s\n" "$icon" "$project" "$state"
