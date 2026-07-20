#!/bin/sh
# Fleet operations across every repo stamped from these templates.
# Usage: fleet.sh [-v] [stamp]
#   (no verb)  Sweep: run doctor.sh on each fleet repo and print one summary
#              line per repo. Read-only; exits nonzero if any repo FAILs.
#   stamp      Re-stamp files the doctor classifies STALE — a verbatim match of
#              an older shipped template, so overwriting provably loses no local
#              information. Working tree only, never a commit; DIVERGED files
#              are never touched. Committing is the operator's (or a skill's) job.
#   -v         Sweep only: print each repo's full doctor output.
# The fleet list comes from $FLEET_FILE (default: <this repo>/fleet.txt,
# gitignored; one path per line, absolute or relative to this repo, '#'
# comments). Without one, discovery: sibling directories of this repo that are
# git repos and look stamped (.githooks/ or AGENTS.md).

std_root=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
tpl="$std_root/templates"
fleet_file="${FLEET_FILE:-$std_root/fleet.txt}"

verbose=0
verb=sweep
for arg in "$@"; do
  case "$arg" in
    -v) verbose=1 ;;
    stamp) verb=stamp ;;
    *) echo "Usage: fleet.sh [-v] [stamp]"; exit 2 ;;
  esac
done

list=$(mktemp)
scratch=$(mktemp)
trap 'rm -f "$list" "$scratch"' EXIT

if [ -f "$fleet_file" ]; then
  grep -v '^#' "$fleet_file" | grep -v '^[[:space:]]*$' | while IFS= read -r line; do
    case "$line" in
      /*) printf '%s\n' "$line" ;;
      *) printf '%s/%s\n' "$std_root" "$line" ;;
    esac
  done > "$list"
else
  for d in "$std_root"/../*/; do
    dp=$(CDPATH='' cd -- "$d" 2>/dev/null && pwd) || continue
    [ "$dp" = "$std_root" ] && continue
    [ -d "$dp/.git" ] || continue
    if [ -d "$dp/.githooks" ] || [ -f "$dp/AGENTS.md" ]; then
      printf '%s\n' "$dp"
    fi
  done > "$list"
fi

[ -s "$list" ] || { echo "fleet.sh: no fleet repos found ($fleet_file, or sibling discovery)"; exit 2; }

# Map the doctor's drift warnings back to file names ("hook" is commit-msg).
drift() { # $1 = doctor output, $2 = stale|diverged
  case "$2" in
    stale) m='is a stale template copy' ;;
    *) m='diverged' ;;
  esac
  printf '%s\n' "$1" | sed -nE "s/^WARN  (hook|pre-commit|secret-scan|AGENTS\.md) $m.*/\1/p" \
    | sed 's/^hook$/commit-msg/'
}

bad=0
while IFS= read -r repo; do
  name=$(basename "$repo")
  if out=$("$std_root/doctor.sh" "$repo" 2>&1); then rc=0; else rc=$?; fi
  if [ "$rc" -ge 2 ]; then
    printf '%-20s ERROR — doctor could not run (exit %s)\n' "$name" "$rc"
    bad=$((bad + 1))
    continue
  fi

  if [ "$verb" = stamp ]; then
    drift "$out" stale > "$scratch"
    stamped=""
    while IFS= read -r f; do
      case "$f" in
        commit-msg)
          types=$(sed -n 's/^types="\(.*\)"$/\1/p' "$repo/.githooks/commit-msg")
          scopes=$(sed -n 's/^scopes="\(.*\)"$/\1/p' "$repo/.githooks/commit-msg")
          sed -e "s,^types=.*,types=\"$types\"," -e "s,^scopes=.*,scopes=\"$scopes\"," \
            "$tpl/githooks/commit-msg" > "$repo/.githooks/commit-msg"
          chmod +x "$repo/.githooks/commit-msg" ;;
        pre-commit|secret-scan)
          cp "$tpl/githooks/$f" "$repo/.githooks/$f"
          chmod +x "$repo/.githooks/$f" ;;
        AGENTS.md)
          cp "$tpl/AGENTS.md" "$repo/AGENTS.md" ;;
      esac
      stamped="$stamped $f"
    done < "$scratch"
    skipped=$(drift "$out" diverged | paste -sd, -)
    if [ -n "$stamped" ]; then
      printf '%-20s restamped:%s (uncommitted — review and commit per repo)\n' "$name" "$stamped"
    else
      printf '%-20s clean — nothing stale\n' "$name"
    fi
    [ -n "$skipped" ] && printf '%-20s untouched (diverged, deliberate): %s\n' '' "$skipped"
    continue
  fi

  summary=$(printf '%s\n' "$out" | sed -n 's/^== summary: \(.*\) ==$/\1/p')
  stale=$(drift "$out" stale | paste -sd, -)
  [ -n "$stale" ] || stale=-
  div=$(drift "$out" diverged | paste -sd, -)
  [ -n "$div" ] || div=-
  printf '%-20s %-16s stale: %-24s diverged: %s\n' "$name" "$summary" "$stale" "$div"
  [ "$verbose" -eq 1 ] && printf '%s\n\n' "$out"
  [ "$rc" -ne 0 ] && bad=$((bad + 1))
done < "$list"

if [ "$verb" = sweep ]; then
  [ "$bad" -eq 0 ] || { echo "== fleet: $bad repo(s) failing =="; exit 1; }
fi
exit 0
