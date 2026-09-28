#!/usr/bin/env bash
# Antigravity CLI window title: agent state + workspace name.
#
# Payload/config shape (title.command in ~/.gemini/antigravity-cli/settings.json,
# JSON on stdin with .agent_state / .workspace.current_dir) per
# https://glaforge.dev/posts/2026/06/07/customizing-antigravity-cli-title-and-statusline/
# -- not yet cross-checked against a captured live payload on this
# machine, so field lookups fall back gracefully (.cwd, "unknown")
# rather than erroring if a name turns out wrong.
#
# Must NOT emit ANSI/escape sequences here -- the CLI does the actual
# window-title injection itself, unlike the statusline command.

input=$(cat)

state=$(echo "$input" | jq -r '.agent_state // "unknown"')
workspace=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
workspace_name=$(basename "$workspace")

case "$state" in
    idle)     icon="💤" ;;
    thinking) icon="🤔" ;;
    running)  icon="⚙️" ;;
    error)    icon="❌" ;;
    *)        icon="🛰️" ;;
esac

printf "%s Antigravity: %s — %s\n" "$icon" "$state" "$workspace_name"
