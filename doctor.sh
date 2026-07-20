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
else
  warn "no .githooks/pre-commit — gate-green-before-commit is prose only (init.sh installs one)"
fi
if [ -x "$target/.githooks/secret-scan" ]; then
  pass ".githooks/secret-scan exists"
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
  if cmp -s "$tpl/AGENTS.md" "$target/AGENTS.md"; then
    pass "AGENTS.md present and identical to the template"
  else
    warn "AGENTS.md drifted from the template (diff \"$tpl/AGENTS.md\" \"$target/AGENTS.md\")"
  fi
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
