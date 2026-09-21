#!/bin/bash
input=$(cat)

# Colors
RESET='\033[0m'
DIM='\033[2m'
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
SEP="${DIM} | ${RESET}"

# 1. Git branch and status
cwd=$(echo "$input" | jq -r '.cwd // empty')
if [ -n "$cwd" ]; then
  git_branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)
  git_dir=$(git -C "$cwd" rev-parse --git-dir 2>/dev/null)
  git_dirty=$(git -C "$cwd" status --porcelain 2>/dev/null | head -1)
else
  git_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  git_dir=$(git rev-parse --git-dir 2>/dev/null)
  git_dirty=$(git status --porcelain 2>/dev/null | head -1)
fi

worktree_label=""
case "$git_dir" in
  */.git/worktrees/*) worktree_label=" (worktree)" ;;
esac

if [ -n "$git_branch" ]; then
  if [ -z "$git_dirty" ]; then
    status_indicator="${GREEN}✓${RESET}"
  else
    status_indicator="${YELLOW}●${RESET}"
  fi
  git_section="${CYAN}${git_branch}${worktree_label}${RESET} ${status_indicator}"
else
  git_section="${DIM}no git${RESET}"
fi

model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
model_section="${CYAN}${model}${RESET}"

# 2. Context window progress bar with color thresholds
input_tokens=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

if [ "$input_tokens" -lt 80000 ] 2>/dev/null; then
  bar_color="$GREEN"
elif [ "$input_tokens" -lt 120000 ] 2>/dev/null; then
  bar_color="$YELLOW"
else
  bar_color="$RED"
fi

if [ -n "$used_pct" ]; then
  used_int=$(printf "%.0f" "$used_pct")
else
  used_int=0
fi

bar_filled=$((used_int / 5))
bar_empty=$((20 - bar_filled))
[ "$bar_filled" -gt 20 ] && bar_filled=20
[ "$bar_empty" -lt 0 ] && bar_empty=0

bar=""
i=0
while [ "$i" -lt "$bar_filled" ]; do
  bar="${bar}█"
  i=$((i + 1))
done
i=0
while [ "$i" -lt "$bar_empty" ]; do
  bar="${bar}░"
  i=$((i + 1))
done

ctx_section="${bar_color}[${bar}] ${used_int}%${RESET}"

# 3. Stats: cost, duration, api time, lines changed
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
api_ms=$(echo "$input" | jq -r '.cost.total_api_duration_ms // 0')
lines_added=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
lines_removed=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')

cost_display=$(printf "\$%.2f" "$cost")

fmt_duration() {
  local total_s=$(( $1 / 1000 ))
  local d=$(( total_s / 86400 ))
  local h=$(( (total_s % 86400) / 3600 ))
  local m=$(( (total_s % 3600) / 60 ))
  local s=$(( total_s % 60 ))
  if [ "$d" -gt 0 ]; then
    printf "%dd %dh %02dm" "$d" "$h" "$m"
  elif [ "$h" -gt 0 ]; then
    printf "%dh %02dm %02ds" "$h" "$m" "$s"
  else
    printf "%dm %02ds" "$m" "$s"
  fi
}

api_display=$(fmt_duration "$api_ms")

lines_display="${GREEN}+${lines_added}${RESET} ${RED}-${lines_removed}${RESET}"

stats_section="${cost_display} · ${api_display} · ${lines_display}"

# Output
printf '%b\n' "${git_section}${SEP}${model_section}${SEP}${ctx_section}${SEP}${stats_section}"
