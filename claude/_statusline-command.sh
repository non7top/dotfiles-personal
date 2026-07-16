#!/usr/bin/env bash
# Claude Code status line: git info + usage bars
# Shared rendering logic lives in ~/.statusline-common.sh (see there
# for why -- also used by the Antigravity CLI statusline).

source "$HOME/.statusline-common.sh"

input=$(cat)

ctx_pct=$(echo "$input"        | jq -r '(.context_window.used_percentage // 0) | round')
sess_pct=$(echo "$input"       | jq -r '(.rate_limits.five_hour.used_percentage // 0) | round')
resets_at=$(echo "$input"      | jq -r '.rate_limits.five_hour.resets_at // 0')
week_pct=$(echo "$input"       | jq -r '(.rate_limits.seven_day.used_percentage // 0) | round')
week_resets_at=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // 0')
branch=$(echo "$input"         | jq -r '.worktree.branch // ""')
cwd=$(echo "$input"            | jq -r '.cwd // ""')
[ -z "$branch" ] && branch=$(git --no-optional-locks -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)

now=$(date +%s)
reset_str=$(sl_fmt_reset $(( resets_at - now )))
week_reset_str=$(sl_fmt_workdays $(( week_resets_at - now )))

ctx_color=$(sl_color_for_pct "$ctx_pct" 70 80 "$sl_green")
sess_color=$(sl_color_for_pct "$sess_pct" 50 80 "$sl_cyan")
week_color=$(sl_color_for_pct "$week_pct" 50 80 "$sl_magenta")

git_seg=$(sl_git_segment "$cwd" "$branch")

sl_usage_segment "$ctx_pct" "$ctx_color" "ctx" "" ctx_seg narrow_ctx_seg
sl_usage_segment "$sess_pct" "$sess_color" "5h" " ↺ ${reset_str}" sess_seg narrow_sess_seg
sl_usage_segment "$week_pct" "$week_color" "7d" " ↺ ${week_reset_str}" week_seg narrow_week_seg

wide_bars="${ctx_seg}  ${sess_seg}  ${week_seg}"
narrow_bars="${narrow_ctx_seg}/${narrow_sess_seg}/${narrow_week_seg}"

# ui_margin accounts for Claude Code's own chrome (2 left indent + 1
# right reserve) beyond $COLUMNS.
sl_render_line "$git_seg" "$wide_bars" "$narrow_bars" "$COLUMNS" 3
