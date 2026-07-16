# Shared helpers for the Claude Code and Antigravity CLI statuslines
# (~/.claude/statusline-command.sh and ~/.gemini/statusline-command.sh).
# Both source this file rather than duplicating segment-rendering logic.
# See statusline-README.md for the broader pattern this follows (also
# shared conceptually with _bashrc's PS1 generator).

sl_reset="\033[0m"
sl_yellow="\033[33m"
sl_light_yellow="\033[93m"
sl_magenta="\033[35m"
sl_green="\033[32m"
sl_red="\033[31m"
sl_cyan="\033[36m"

# Renders a colored segment, interpreting its \033 escapes into real bytes.
sl_seg() { printf "$1"; }

# Strips ANSI color codes, for measuring visible (non-escape) width.
sl_strip_ansi() { printf '%s' "$1" | sed -E 's/\x1b\[[0-9;]*m//g'; }

# Build a block bar (default 4 chars wide) for a 0-100 percentage.
sl_make_bar() {
    local pct=$1 width=${2:-4}
    local filled
    filled=$(awk "BEGIN { printf \"%.0f\", ($pct / 100) * $width }")
    local empty=$(( width - filled ))
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty;  i++)); do bar+="░"; done
    echo "$bar"
}

# Threshold-band color for a percentage: red >= high, yellow >= low, else base.
sl_color_for_pct() {
    local pct=$1 low=$2 high=$3 base_color=$4
    if   [ "$pct" -ge "$high" ]; then echo "$sl_red"
    elif [ "$pct" -ge "$low" ];  then echo "$sl_yellow"
    else                              echo "$base_color"
    fi
}

# "Xh" (whole hours, floored) / "Ym" (minutes, only when under 1h) /
# "now" from a count of seconds remaining (already relative --
# callers compute `resets_at - now` or use a relative field directly,
# since the two tools give reset times differently).
sl_fmt_reset() {
    local secs_left=$1
    if [ "$secs_left" -le 0 ]; then
        echo "now"
    else
        local h=$(( secs_left / 3600 ))
        local m=$(( (secs_left % 3600) / 60 ))
        [ "$h" -gt 0 ] && echo "${h}h" || echo "${m}m"
    fi
}

# Work-days (Mon-Fri) until a count of seconds remaining.
sl_fmt_workdays() {
    local secs_left=$1
    if [ "$secs_left" -le 0 ]; then
        echo "now"
        return
    fi
    local now
    now=$(date +%s)
    local target=$(( now + secs_left ))
    local wd=0
    local cur=$now
    while [ "$cur" -lt "$target" ]; do
        local dow
        dow=$(date -d "@$cur" +%u 2>/dev/null || date -r "$cur" +%u 2>/dev/null)
        [ "$dow" -lt 6 ] && wd=$(( wd + 1 ))
        cur=$(( cur + 86400 ))
    done
    [ "$wd" -eq 1 ] && echo "${wd} day" || echo "${wd} days"
}

# Git segment: "<dirname> [<branch>] +N -M" or "not in git repo".
# cwd and branch are passed in since each tool sources branch/cwd
# differently (Claude: .worktree.branch + git fallback; Antigravity:
# .vcs.branch directly).
sl_git_segment() {
    local cwd=$1 branch=$2
    local dir_name
    dir_name=$(basename "$cwd")

    if [ -z "$branch" ]; then
        sl_seg "${sl_light_yellow}not in git repo${sl_reset}"
        return
    fi

    local diff_stat added removed diff_part
    diff_stat=$(git --no-optional-locks -C "$cwd" diff --shortstat HEAD 2>/dev/null)
    added=$(echo "$diff_stat"   | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+')
    removed=$(echo "$diff_stat" | grep -oE '[0-9]+ deletion'  | grep -oE '[0-9]+')
    [ -z "$added" ]   && added=0
    [ -z "$removed" ] && removed=0

    diff_part=""
    [ "$added"   -gt 0 ] && diff_part="${diff_part} ${sl_green}+${added}${sl_reset}"
    [ "$removed" -gt 0 ] && diff_part="${diff_part} ${sl_red}-${removed}${sl_reset}"

    sl_seg "${sl_yellow}${dir_name}${sl_reset} ${sl_magenta}[${branch}]${sl_reset}${diff_part}"
}

# Renders one "<label> [<bar>] <pct>% <reset-suffix>" segment plus its
# bare-percentage narrow-mode counterpart. Sets the two result
# variables named by $3/$4 (bash has no return-by-value for strings).
#   sl_usage_segment <pct> <color> <label> <reset_suffix> wide_var narrow_var
sl_usage_segment() {
    local pct=$1 color=$2 label=$3 reset_suffix=$4
    local -n _wide=$5 _narrow=$6
    local bar
    bar=$(sl_make_bar "$pct")
    _wide=$(sl_seg "${color}${label} [${bar}] ${pct}%%${reset_suffix}${sl_reset}")
    _narrow=$(sl_seg "${color}${pct}${sl_reset}")
}

# Right-aligns `$bars` against the terminal edge given `$git_seg` on
# the left and `$cols` total width, with `$margin` reserved for the
# host tool's own chrome. Prints the final line.
sl_render_line() {
    local git_seg=$1 wide_bars=$2 narrow_bars=$3 cols=$4 margin=$5

    local git_visible wide_visible
    git_visible=$(sl_strip_ansi "$git_seg")
    wide_visible=$(sl_strip_ansi "$wide_bars")

    local bars
    if [ $(( cols - margin - ${#git_visible} - ${#wide_visible} )) -ge 1 ]; then
        bars="$wide_bars"
    else
        bars="$narrow_bars"
    fi

    local bars_visible pad
    bars_visible=$(sl_strip_ansi "$bars")
    pad=$(( cols - margin - ${#git_visible} - ${#bars_visible} ))
    [ "$pad" -lt 1 ] && pad=1

    printf "%s%*s%s\n" "$git_seg" "$pad" "" "$bars"
}
