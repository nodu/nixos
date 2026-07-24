#!/usr/bin/env bash
# Claude Code status line: model · dir · context usage / tokens / % left · cost
# Reads the status JSON payload on stdin. See https://code.claude.com/docs/en/statusline.md
input=$(cat)

# --- extract fields (jq; fields may be null/absent early in a session) ---
# newline-delimited so empty fields are preserved (mapfile keeps blank lines)
mapfile -t F < <(
  printf '%s' "$input" | jq -r '
    ( .model.display_name // "Claude" ),
    ( .workspace.current_dir // .cwd // "" ),
    ( .context_window.used_percentage      | if . == null then "" else . end ),
    ( .context_window.remaining_percentage | if . == null then "" else . end ),
    ( .context_window.total_input_tokens   | if . == null then "" else . end ),
    ( .context_window.context_window_size  | if . == null then "" else . end ),
    ( .cost.total_cost_usd                 | if . == null then "" else . end )'
)
model=${F[0]}; dir=${F[1]}; used_pct=${F[2]}; remain_pct=${F[3]}
used_tok=${F[4]}; ctx_size=${F[5]}; cost=${F[6]}

dir_name=$(basename "$dir")

# --- helpers ---
fmt_tokens() { awk -v n="$1" 'BEGIN{
  if (n=="") { print ""; exit }
  if (n>=1000000) printf "%.1fM", n/1000000;
  else if (n>=1000) printf "%dk", int(n/1000+0.5);
  else printf "%d", n;
}'; }

# ANSI colors
DIM='\033[2m'; RESET='\033[0m'
CYAN='\033[36m'; BLUE='\033[34m'
GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'
SEP="${DIM} · ${RESET}"

# --- context segment ---
ctx_seg=""
if [ -n "$used_pct" ]; then
  used_int=$(printf '%.0f' "$used_pct")
  remain_int=$(printf '%.0f' "${remain_pct:-$(awk -v u="$used_pct" 'BEGIN{print 100-u}')}")
  # color by how much context is LEFT
  if   [ "$remain_int" -le 15 ]; then ctx_color="$RED"
  elif [ "$remain_int" -le 35 ]; then ctx_color="$YELLOW"
  else ctx_color="$GREEN"; fi
  tok_str=""
  if [ -n "$used_tok" ] && [ -n "$ctx_size" ]; then
    tok_str=" ${DIM}($(fmt_tokens "$used_tok")/$(fmt_tokens "$ctx_size"))${RESET}"
  fi
  ctx_seg="${ctx_color}${remain_int}% left${RESET}${tok_str}"
else
  ctx_seg="${DIM}ctx —${RESET}"
fi

# --- cost segment ---
cost_seg=""
if [ -n "$cost" ]; then
  cost_seg="${SEP}${DIM}\$$(printf '%.2f' "$cost")${RESET}"
fi

printf "${CYAN}%s${RESET}${SEP}${BLUE}%s${RESET}${SEP}%b${cost_seg}\n" \
  "$model" "$dir_name" "$ctx_seg"
