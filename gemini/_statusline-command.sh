#!/usr/bin/env bash
# Antigravity CLI status line: git info + context/quota bars.
# Shared rendering logic lives in ~/.statusline-common.sh (see there
# for why -- also used by the Claude Code statusline).
#
# Antigravity can run on native Gemini models or third-party ones
# (Claude/GPT) underneath, each metered separately, so there are two
# quota pairs (5h/weekly) instead of Claude's one.

source "$HOME/.statusline-common.sh"

input=$(cat)

ctx_pct=$(echo "$input"  | jq -r '(.context_window.used_percentage // 0) | round')
branch=$(echo "$input"   | jq -r '.vcs.branch // ""')
cwd=$(echo "$input"      | jq -r '.cwd // ""')
cols=$(echo "$input"     | jq -r '.terminal_width // 80')

# Antigravity gives *remaining fraction* + *relative* seconds-to-reset,
# the inverse of Claude's *used percentage* + *absolute* epoch.
gem5h_pct=$(echo "$input"      | jq -r '(1 - (.quota["gemini-5h"].remaining_fraction // 1)) * 100 | round')
gem5h_resets_in=$(echo "$input" | jq -r '.quota["gemini-5h"].reset_in_seconds // 0')
gemwk_pct=$(echo "$input"      | jq -r '(1 - (.quota["gemini-weekly"].remaining_fraction // 1)) * 100 | round')
gemwk_resets_in=$(echo "$input" | jq -r '.quota["gemini-weekly"].reset_in_seconds // 0')
p3p5h_pct=$(echo "$input"      | jq -r '(1 - (.quota["3p-5h"].remaining_fraction // 1)) * 100 | round')
p3p5h_resets_in=$(echo "$input" | jq -r '.quota["3p-5h"].reset_in_seconds // 0')
p3pwk_pct=$(echo "$input"      | jq -r '(1 - (.quota["3p-weekly"].remaining_fraction // 1)) * 100 | round')
p3pwk_resets_in=$(echo "$input" | jq -r '.quota["3p-weekly"].reset_in_seconds // 0')

gem5h_reset_str=$(sl_fmt_reset "$gem5h_resets_in")
gemwk_reset_str=$(sl_fmt_workdays "$gemwk_resets_in")
p3p5h_reset_str=$(sl_fmt_reset "$p3p5h_resets_in")
p3pwk_reset_str=$(sl_fmt_workdays "$p3pwk_resets_in")

ctx_color=$(sl_color_for_pct "$ctx_pct" 70 80 "$sl_green")
gem5h_color=$(sl_color_for_pct "$gem5h_pct" 50 80 "$sl_cyan")
gemwk_color=$(sl_color_for_pct "$gemwk_pct" 50 80 "$sl_magenta")
p3p5h_color=$(sl_color_for_pct "$p3p5h_pct" 50 80 "$sl_cyan")
p3pwk_color=$(sl_color_for_pct "$p3pwk_pct" 50 80 "$sl_magenta")

git_seg=$(sl_git_segment "$cwd" "$branch")

sl_usage_segment "$ctx_pct" "$ctx_color" "ctx" "" ctx_seg narrow_ctx_seg
sl_usage_segment "$gem5h_pct" "$gem5h_color" "gem5h" " ↺ ${gem5h_reset_str}" gem5h_seg narrow_gem5h_seg
sl_usage_segment "$gemwk_pct" "$gemwk_color" "gemwk" " ↺ ${gemwk_reset_str}" gemwk_seg narrow_gemwk_seg
sl_usage_segment "$p3p5h_pct" "$p3p5h_color" "3p5h" " ↺ ${p3p5h_reset_str}" p3p5h_seg narrow_p3p5h_seg
sl_usage_segment "$p3pwk_pct" "$p3pwk_color" "3pwk" " ↺ ${p3pwk_reset_str}" p3pwk_seg narrow_p3pwk_seg

wide_bars="${ctx_seg}  ${gem5h_seg}  ${gemwk_seg}  ${p3p5h_seg}  ${p3pwk_seg}"
narrow_bars="${narrow_ctx_seg}/${narrow_gem5h_seg}/${narrow_gemwk_seg}/${narrow_p3p5h_seg}/${narrow_p3pwk_seg}"

sl_render_line "$git_seg" "$wide_bars" "$narrow_bars" "$cols" 3
