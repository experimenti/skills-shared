#!/usr/bin/env bash
# shots.sh — list the newest screenshots in the ShareX drop folder for the /shots skill.
#
#   shots.sh            newest 1          shots.sh 3      newest 3 (max 20)
#   shots.sh '#4'       the 4th newest    shots.sh list   20 newest, read nothing
#
# Config (environment, e.g. "env" in ~/.claude/settings.json):
#   SHOT_DIR         drop folder. A Windows path (E:\shots, E:/shots) is mapped to
#                    /mnt/e/shots under WSL or /e/shots under Git Bash; POSIX paths pass through.
#   SHOT_PRUNE_DAYS  optional. Delete images older than this many days from the TOP LEVEL of
#                    SHOT_DIR before listing. Only set it on a dedicated drop folder.
#
# Lives in a file (not inline in SKILL.md) so Claude Code's $0/$1 argument substitution can never
# rewrite the shell. Uses ls/grep/stat only and bash 3.2 syntax, so it runs the same under WSL,
# Git Bash, Linux and macOS.
# SKILL.md passes "$0" (the first word typed). With no words typed Claude Code leaves $0 alone and
# the shell expands it to its own name, which lands here as free text: newest 1.
set -u
DEFAULT_DIR="E:/logs"      # <- change this, or set SHOT_DIR

resolve_dir() {            # Windows drive path -> whatever mount this shell can see
  local d="$1" drive rest
  case "$d" in
    [A-Za-z]:[\\/]*)
      drive=$(printf '%s' "${d:0:1}" | tr '[:upper:]' '[:lower:]')
      rest="${d:2}"; rest="${rest//\\//}"
      if   [ -d "/mnt/$drive" ]; then printf '%s\n' "/mnt/$drive$rest"
      elif [ -d "/$drive" ];     then printf '%s\n' "/$drive$rest"
      else printf '%s\n' "$d"; fi ;;
    *) printf '%s\n' "$d" ;;
  esac
}
age() {                    # seconds -> 42s / 7m / 3h / 2d
  local s=$1
  if   [ "$s" -lt 60 ];    then echo "${s}s"
  elif [ "$s" -lt 3600 ];  then echo "$((s/60))m"
  elif [ "$s" -lt 86400 ]; then echo "$((s/3600))h"
  else                          echo "$((s/86400))d"; fi
}
DIR=$(resolve_dir "${SHOT_DIR:-$DEFAULT_DIR}"); DIR="${DIR%/}"
[ -d "$DIR" ] || { echo "NO_IMAGES_FOUND: $DIR is not a directory (set SHOT_DIR or edit DEFAULT_DIR in ${BASH_SOURCE[0]})"; exit 0; }
SHOW="$DIR"                # paths as printed for the Read tool
case "$(uname -s 2>/dev/null)" in
  MINGW*|MSYS*|CYGWIN*) SHOW=$(cygpath -m -- "$DIR" 2>/dev/null || echo "$DIR") ;;   # Git Bash: E:/logs/x.png, not /e/logs/x.png
esac

# --- arguments ---------------------------------------------------------------
arg="${1:-}"; MODE=newest; K=1
case "$arg" in
  '#'*) n="${arg#\#}"; case "$n" in ''|*[!0-9]*) ;; *) MODE=pick; K=$n ;; esac ;;
  list|ls|all) MODE=list; K=20 ;;
  ''|*[!0-9]*) ;;                          # free text or nothing: newest 1
  *) K=$arg ;;
esac
[ "$K" -ge 1 ] 2>/dev/null || K=1
[ "$MODE" = pick ] || [ "$K" -le 20 ] || K=20

# --- optional pruning ----------------------------------------------------------
if [ "${SHOT_PRUNE_DAYS:-}" != "" ] && [ "$SHOT_PRUNE_DAYS" -gt 0 ] 2>/dev/null; then
  pruned=$(find "$DIR" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.bmp' \) -mtime +"$SHOT_PRUNE_DAYS" -print -delete 2>/dev/null | wc -l)
  [ "$pruned" -gt 0 ] && echo "(pruned $pruned image(s) older than $SHOT_PRUNE_DAYS days)"
fi

# --- listing -----------------------------------------------------------------
# ls -t sorts by mtime (= capture time). current.png is ShareX's fixed-name copy of the newest
# capture, if you kept that action; it would only duplicate row 1.
want=$(( K > 30 ? K : 30 ))
names=(); while IFS= read -r n; do names+=("$n"); done < <(ls -1tp -- "$DIR" 2>/dev/null | grep -iE '\.(png|jpe?g|webp|gif|bmp)$' | grep -vx 'current.png' | head -n "$want")
total=${#names[@]}
[ "$total" -gt 0 ] || { echo "NO_IMAGES_FOUND in $SHOW"; exit 0; }

now=$(date +%s); epochs=(); rows=(); files=()
for n in "${names[@]}"; do files+=("$DIR/$n"); done
# one stat call for every file: process spawns are what cost time under Git Bash and DrvFs
infos=(); while IFS= read -r l; do infos+=("$l"); done < <(stat -c '%Y|%s|%y' -- "${files[@]}" 2>/dev/null || stat -f '%m|%z|%Sm' -t '%Y-%m-%d %H:%M' -- "${files[@]}" 2>/dev/null)
for i in "${!names[@]}"; do
  info=${infos[$i]:-0|0|?}
  ep=${info%%|*}; rest=${info#*|}; bytes=${rest%%|*}; when=${rest#*|}; when=${when:0:16}
  epochs[$i]=$ep
  rows[$i]=$(printf '%2d  %s  %4s  %5s  %s' "$((i+1))" "$when" "$(age $((now-ep)))" "$((bytes/1024))K" "$SHOW/${names[$i]}")
done

case "$MODE" in
  list)
    echo "shots in $SHOW (newest first, listing only):"
    for i in $(seq 0 $(( (total<K?total:K) - 1 ))); do echo "${rows[$i]}"; done
    echo "LISTED ONLY: read nothing yet. Pick with /shots #N (one) or /shots N (newest N)." ;;
  pick)
    echo "shots in $SHOW (newest first):"
    if [ "$K" -le "$total" ]; then
      echo "${rows[$((K-1))]}"; echo "READ: the 1 file above."
    else
      echo "NO_SUCH_SHOT: asked for #$K but only $total image(s) are here."
    fi ;;
  newest)
    shown=$(( total<K ? total : K ))
    echo "shots in $SHOW (newest first):"
    for i in $(seq 0 $((shown-1))); do echo "${rows[$i]}"; done
    [ "$shown" -lt "$K" ] && echo "(only $shown image(s) here)"
    extra=0; for i in $(seq "$shown" $((total-1))); do [ $(( epochs[0] - epochs[$i] )) -le 600 ] && extra=$((extra+1)); done
    [ "$extra" -gt 0 ] && echo "(+$extra more captured within 10 min of the newest: /shots $((shown+extra)) to include them)"
    echo "READ: all $shown file(s) above, newest first." ;;
esac
