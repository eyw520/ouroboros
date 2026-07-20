#!/bin/sh
# Read-only conformance audit of a target repo against the standard.
# Usage: doctor.sh <target-repo>
# Prints PASS/WARN/FAIL per check, a config suggestion derived from commit
# history, and exits nonzero only on FAIL. Never mutates the target.

std_root=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
tpl="$std_root/templates"

target="$1"
[ -n "$target" ] || { echo "Usage: doctor.sh <target-repo>"; exit 2; }
[ -d "$target/.git" ] || { echo "ERROR: $target is not a git repository."; exit 2; }

fails=0
warns=0
pass() { echo "PASS  $1"; }
warn() { echo "WARN  $1"; warns=$((warns + 1)); }
fail() { echo "FAIL  $1"; fails=$((fails + 1)); }

# --- Template drift classification --------------------------------------------
# A target's copy of a stamped file is CURRENT (matches the template as it
# stands), STALE (matches an older shipped version verbatim — safe to re-stamp),
# or DIVERGED (matches no version ever shipped — deliberate; reconcile by hand).
# Judged against this repo's own git history so targets carry no version
# markers; a shallow or history-less copy of this repo degrades stale to diverged.
norm_copy() { # $1 = strip: drop per-repo config lines; anything else: pass through
  if [ "$1" = strip ]; then grep -v -e '^types="' -e '^scopes="'; else cat; fi
}
template_status() { # <target-file> <template-rel-path> [strip]
  ts_tmp=$(mktemp)
  norm_copy "${3:-plain}" < "$1" > "$ts_tmp"
  if norm_copy "${3:-plain}" < "$std_root/$2" | cmp -s - "$ts_tmp"; then
    rm -f "$ts_tmp"
    echo current
    return
  fi
  git -C "$std_root" rev-list HEAD -- "$2" 2>/dev/null | {
    s=diverged
    while IFS= read -r c; do
      if git -C "$std_root" cat-file blob "$c:$2" 2>/dev/null | norm_copy "${3:-plain}" | cmp -s - "$ts_tmp"; then
        s=stale
        break
      fi
    done
    echo "$s"
  }
  rm -f "$ts_tmp"
}

echo "== ouroboros doctor: $target =="

# --- Commit hook -------------------------------------------------------------
hook="$target/.githooks/commit-msg"
if [ -f "$hook" ]; then
  pass ".githooks/commit-msg exists"
  if [ -x "$hook" ]; then pass "hook is executable"; else fail "hook is not executable (chmod +x)"; fi
  types=$(sed -n 's/^types="\(.*\)"$/\1/p' "$hook")
  scopes=$(sed -n 's/^scopes="\(.*\)"$/\1/p' "$hook")
  if [ -n "$types" ]; then
    pass "hook is canonical-shaped (types=\"$types\" scopes=\"$scopes\")"
    case "$(template_status "$hook" "templates/githooks/commit-msg" strip)" in
      current) pass "hook matches the current template (config aside)" ;;
      stale)   warn "hook is a stale template copy (config aside) — re-stamp from the template" ;;
      *)       warn "hook diverged from every shipped template version — deliberate? reconcile by hand" ;;
    esac
  else
    warn "hook is not the canonical template (no types= variable); its regex is still the source of truth"
  fi
else
  fail "no .githooks/commit-msg (init.sh installs one; derive types/scopes from the histogram below)"
fi

if [ -f "$target/.githooks/pre-commit" ]; then
  if [ -x "$target/.githooks/pre-commit" ]; then
    pass ".githooks/pre-commit exists (gate-green-before-commit is enforced)"
  else
    fail ".githooks/pre-commit is not executable — git silently skips it (chmod +x)"
  fi
  case "$(template_status "$target/.githooks/pre-commit" "templates/githooks/pre-commit")" in
    current) : ;;
    stale)   warn "pre-commit is a stale template copy — re-stamp from the template" ;;
    *)       warn "pre-commit diverged from every shipped template version — deliberate (scoped variant)? keep it reconciled" ;;
  esac
else
  warn "no .githooks/pre-commit — gate-green-before-commit is prose only (init.sh installs one)"
fi
if [ -x "$target/.githooks/secret-scan" ]; then
  pass ".githooks/secret-scan exists"
  case "$(template_status "$target/.githooks/secret-scan" "templates/githooks/secret-scan")" in
    current) : ;;
    stale)   warn "secret-scan is a stale template copy — upstream patterns are newer; re-stamp and re-apply local exemptions" ;;
    *)       warn "secret-scan diverged from every shipped template version — local extensions are fine, but fold in upstream pattern updates" ;;
  esac
else
  warn "no .githooks/secret-scan (init.sh installs it; pre-commit and doctor call it)"
fi

hookspath=$(git -C "$target" config core.hooksPath)
if [ "$hookspath" = ".githooks" ]; then
  pass "core.hooksPath wired to .githooks"
else
  fail "core.hooksPath is '${hookspath:-unset}' — the hook never runs (make hooks / init.sh wires it)"
fi

# --- Empirical conformance: replay recent subjects through the hook ----------
if [ -f "$hook" ] && [ -x "$hook" ] && [ "$(git -C "$target" rev-list --count HEAD 2>/dev/null || echo 0)" -gt 0 ]; then
  tmp_subj=$(mktemp)
  tmp_list=$(mktemp)
  git -C "$target" log --format=%s -20 > "$tmp_list"
  bad=0
  while IFS= read -r s; do
    printf '%s\n' "$s" > "$tmp_subj"
    "$hook" "$tmp_subj" >/dev/null 2>&1 || bad=$((bad + 1))
  done < "$tmp_list"
  rm -f "$tmp_subj" "$tmp_list"
  if [ "$bad" -eq 0 ]; then
    pass "last 20 commit subjects all satisfy the hook"
  else
    warn "$bad of the last 20 commit subjects fail the hook (drift between hook and practice — reconcile toward observed history)"
  fi
fi

# --- Docs --------------------------------------------------------------------
if [ -f "$target/AGENTS.md" ]; then
  case "$(template_status "$target/AGENTS.md" "templates/AGENTS.md")" in
    current) pass "AGENTS.md present and identical to the template" ;;
    stale)   warn "AGENTS.md is a stale template copy — re-sync from templates/AGENTS.md" ;;
    *)       warn "AGENTS.md diverged from every shipped template version (diff \"$tpl/AGENTS.md\" \"$target/AGENTS.md\")" ;;
  esac
else
  fail "no AGENTS.md (init.sh installs it)"
fi

if [ -f "$target/CLAUDE.md" ]; then
  if grep -q '^@AGENTS.md$' "$target/CLAUDE.md"; then
    pass "CLAUDE.md imports @AGENTS.md"
  else
    warn "CLAUDE.md does not import @AGENTS.md (add the import near the top, then dedupe overlapping conventions)"
  fi
  if grep -qn 'Commit messages:' "$target/CLAUDE.md"; then
    echo "INFO  CLAUDE.md documents a commit format — verify it matches the hook exactly:"
    grep -n 'Commit messages:' "$target/CLAUDE.md" | head -2 | sed 's/^/      /'
  fi
else
  warn "no CLAUDE.md (templates/CLAUDE.md is the skeleton)"
fi

# --- Context budget: keep the always-loaded docs lean ------------------------
# CLAUDE.md and everything it @-imports load into agent context every session;
# unbounded growth is runaway context. One-sentence-per-line house style makes
# the non-blank line count a faithful proxy for prose volume. WARN, not FAIL:
# a budget is a nudge to trim, not a wall (density beats a hard line ceiling).
context_budget=150
if [ -f "$target/CLAUDE.md" ]; then
  loaded="CLAUDE.md"
  total=$(grep -vc '^[[:space:]]*$' "$target/CLAUDE.md")
  # Direct @-imports (one level): a line starting with @ names a path to pull in.
  imp_list=$(mktemp)
  sed -n 's/^@\([^[:space:]]*\).*/\1/p' "$target/CLAUDE.md" > "$imp_list"
  while IFS= read -r imp; do
    [ -f "$target/$imp" ] || continue
    total=$((total + $(grep -vc '^[[:space:]]*$' "$target/$imp")))
    loaded="$loaded + $imp"
  done < "$imp_list"
  rm -f "$imp_list"
  if [ "$total" -le "$context_budget" ]; then
    pass "always-loaded docs within context budget ($total/$context_budget non-blank lines: $loaded)"
  else
    warn "always-loaded docs over context budget ($total/$context_budget non-blank lines: $loaded) — trim CLAUDE.md; it loads every session"
  fi
fi

if [ -f "$target/.editorconfig" ]; then pass ".editorconfig present"; else warn "no .editorconfig (init.sh installs it)"; fi

# --- Makefile verb contract --------------------------------------------------
mk=""
for f in Makefile makefile; do [ -f "$target/$f" ] && mk="$target/$f" && break; done
if [ -n "$mk" ]; then
  for v in check fmt hooks dev; do
    if grep -qE "^$v:" "$mk"; then
      pass "make $v exists"
    else
      warn "make $v missing (verb contract: check/fmt/hooks/dev, mapped onto the repo's real toolchain)"
    fi
  done
  if grep -qE "^test:" "$mk"; then
    pass "make test exists"
  else
    warn "make test missing — if check already runs tests, alias it; if the repo has no tests, that is the real gap"
  fi
else
  warn "no Makefile — map the verb contract onto the repo's toolchain (templates/python|node/Makefile)"
fi

# --- Lockfile freshness --------------------------------------------------------
if [ -f "$target/uv.lock" ]; then
  if command -v uv >/dev/null 2>&1; then
    if (cd "$target" && uv lock --check >/dev/null 2>&1) || (cd "$target" && uv lock --locked >/dev/null 2>&1); then
      pass "uv.lock is fresh against pyproject.toml"
    else
      warn "uv.lock is STALE against pyproject.toml — a fresh checkout fails; refresh as its own commit"
    fi
  else
    echo "INFO  uv.lock present but uv unavailable; freshness unchecked"
  fi
fi
if [ -f "$target/poetry.lock" ]; then
  warn "poetry is superseded by uv (DECISIONS.md has the migration recipe)"
  if command -v poetry >/dev/null 2>&1; then
    if (cd "$target" && poetry check --lock >/dev/null 2>&1); then
      pass "poetry.lock is fresh against pyproject.toml"
    else
      warn "poetry.lock is STALE against pyproject.toml — a fresh checkout fails; refresh as its own commit"
    fi
  else
    echo "INFO  poetry.lock present but poetry unavailable; freshness unchecked"
  fi
fi

# --- CI ----------------------------------------------------------------------
remote=$(git -C "$target" remote get-url origin 2>/dev/null)
gate="$target/.github/workflows/gate.yml"
if [ -f "$gate" ]; then
  if grep -q 'make check' "$gate"; then
    pass "CI gate runs make check"
  else
    warn "CI gate exists but does not run make check (CI must run the gate, nothing else)"
  fi
else
  case "$remote" in
    *github.com*) warn "GitHub remote but no .github/workflows/gate.yml (templates/github/workflows/gate.yml)" ;;
    *) echo "INFO  no GitHub remote; CI not applicable" ;;
  esac
fi

# --- Security ----------------------------------------------------------------
leaks=$(git -C "$target" ls-files | grep -E '\.pem$|\.key$|(^|/)id_rsa|(^|/)secrets\.(env|json)$' || true)
if [ -n "$leaks" ]; then
  fail "credential-shaped FILENAMES are tracked (flag to the operator; do not rewrite history unilaterally):"
  echo "$leaks" | sed 's/^/      /'
else
  pass "no credential-shaped tracked filenames"
fi

scanner="$target/.githooks/secret-scan"
[ -x "$scanner" ] || scanner="$tpl/githooks/secret-scan"
if (cd "$target" && "$scanner" --tracked >/dev/null 2>&1); then
  pass "content secret scan clean ($(basename "$(dirname "$scanner")")/secret-scan --tracked)"
else
  fail "content secret scan found credential-shaped VALUES — rerun for redacted locations: (cd $target && $scanner --tracked)"
fi

# --- Config suggestion from history ------------------------------------------
if [ "$(git -C "$target" rev-list --count HEAD 2>/dev/null || echo 0)" -gt 0 ]; then
  echo "== type(scope) histogram, last 100 subjects (derive -t/-s for init.sh from this) =="
  git -C "$target" log --format=%s -100 \
    | sed -E -e 's/^([a-z]+)\(([^)]*)\): .*/\1(\2)/' -e 't' \
             -e 's/^([a-z]+): .*/\1/' -e 't' \
             -e 's/.*/NONCONFORMING/' \
    | sort | uniq -c | sort -rn | head -10
fi

echo "== summary: $fails fail, $warns warn =="
[ "$fails" -eq 0 ]
