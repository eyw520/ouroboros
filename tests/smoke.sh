#!/usr/bin/env bash
# Smoke suite for the ouroboros tooling: stamps scratch repos and asserts the
# hook, scanner, and doctor behave. Zero dependencies beyond git + bash.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

# --- the target-blindness invariant --------------------------------------------
# Nothing stamped into a repo may reveal that this repo exists: no names, no
# version markers, no references to its scripts or docs.
if grep -rilE 'ouroboros|PATTERNS\.md|DECISIONS\.md|BLUEPRINT|init\.sh|doctor\.sh' templates/; then
  fail "a template leaks this repo's existence (files above)"
fi

# --- stamp: scoped python repo ------------------------------------------------
git init -q "$tmp/repo"
./init.sh -s "all|agent" -l python -c "$tmp/repo" > /dev/null || fail "init.sh (scoped) errored"
for f in .githooks/commit-msg .githooks/pre-commit .githooks/secret-scan \
         AGENTS.md CLAUDE.md .editorconfig Makefile ruff.toml mypy.ini \
         pyrightconfig.json .python-version .github/workflows/gate.yml; do
  [ -f "$tmp/repo/$f" ] || fail "stamp missing $f"
done
[ -x "$tmp/repo/.githooks/pre-commit" ] || fail "pre-commit not executable"
[ -x "$tmp/repo/.githooks/secret-scan" ] || fail "secret-scan not executable"
[ "$(git -C "$tmp/repo" config core.hooksPath)" = ".githooks" ] || fail "hooksPath not wired"

# --- commit-msg: scoped form --------------------------------------------------
msg() { printf '%s\n' "$1" > "$tmp/m"; "$tmp/repo/.githooks/commit-msg" "$tmp/m" > /dev/null 2>&1; }
msg 'feat(all): Good subject.' || fail "scoped hook rejected a good subject"
msg 'feat: Missing scope.' && fail "scoped hook accepted a scopeless subject"
msg 'feet(all): Wrong type.' && fail "hook accepted a wrong type"
msg 'garbage' && fail "hook accepted garbage"

# --- commit-msg: git-generated messages pass untouched --------------------------
msg 'fixup! feat(all): Anything at all' || fail "hook rejected a fixup! subject"
msg "Merge branch 'main' into feature" || fail "hook rejected a merge subject"
printf 'Revert "feat(all): Ok."\n\nThis reverts commit 123abc.\n' > "$tmp/m"
"$tmp/repo/.githooks/commit-msg" "$tmp/m" > /dev/null 2>&1 || fail "hook rejected a git-generated revert"

# --- commit-msg: cosmetic auto-fix ---------------------------------------------
msg 'feat(all): add user auth' || fail "hook rejected an auto-fixable subject"
[ "$(head -1 "$tmp/m")" = 'feat(all): Add user auth.' ] || fail "auto-fix produced: $(head -1 "$tmp/m")"
msg 'fix(all): Trailing space.   ' || fail "hook rejected a trailing-space subject"
[ "$(head -1 "$tmp/m")" = 'fix(all): Trailing space.' ] || fail "trailing-space fix produced: $(head -1 "$tmp/m")"
# shellcheck disable=SC2016  # the backtick is literal, not a substitution
msg 'feat(all): `init` stays idempotent.' || fail "hook rejected a subject opening with a backticked identifier"
msg 'feat(all): ' && fail "hook accepted an empty subject after prefix"
printf 'feat(all): Ok.\n\nA body.\n' > "$tmp/m"
"$tmp/repo/.githooks/commit-msg" "$tmp/m" > /dev/null 2>&1 && fail "hook accepted a body"

# --- commit-msg: scopeless form -----------------------------------------------
git init -q "$tmp/repo2"
./init.sh "$tmp/repo2" > /dev/null || fail "init.sh (scopeless) errored"
printf 'feat: Good subject.\n' > "$tmp/m"
"$tmp/repo2/.githooks/commit-msg" "$tmp/m" > /dev/null 2>&1 || fail "scopeless hook rejected a good subject"
printf 'feat(all): Scoped.\n' > "$tmp/m"
"$tmp/repo2/.githooks/commit-msg" "$tmp/m" > /dev/null 2>&1 && fail "scopeless hook accepted a scope"

# --- init.sh is idempotent and never overwrites -------------------------------
out=$(./init.sh -s "all|agent" -l python -c "$tmp/repo") || fail "init.sh rerun errored"
echo "$out" | grep -q "installed" && fail "rerun reinstalled something"
echo "$out" | grep -q "DIFFERS" && fail "rerun reported DIFFERS on an untouched stamp"
./init.sh -t 'feat,fix' "$tmp/repo" > /dev/null 2>&1 && fail "init.sh accepted a sed-unsafe -t value"

# --- doctor: clean on a fresh stamp, read-only --------------------------------
before=$(git -C "$tmp/repo" status --porcelain)
./doctor.sh "$tmp/repo" > /dev/null || fail "doctor failed on a freshly stamped repo"
after=$(git -C "$tmp/repo" status --porcelain)
[ "$before" = "$after" ] || fail "doctor mutated the target"
chmod -x "$tmp/repo/.githooks/pre-commit"
./doctor.sh "$tmp/repo" > /dev/null 2>&1 && fail "doctor passed a non-executable pre-commit"
chmod +x "$tmp/repo/.githooks/pre-commit"

# --- secret-scan: staged and tracked ------------------------------------------
printf 'key=AKIAABCDEFGHIJKLMNOP\n' > "$tmp/repo/leak.txt"
git -C "$tmp/repo" add leak.txt
(cd "$tmp/repo" && ./.githooks/secret-scan > /dev/null 2>&1) && fail "staged secret passed the scan"
(cd "$tmp/repo" && ./.githooks/secret-scan --tracked > /dev/null 2>&1) && fail "tracked secret passed the scan"
./doctor.sh "$tmp/repo" > /dev/null 2>&1 && fail "doctor passed a repo with a staged secret"
git -C "$tmp/repo" rm -q --cached leak.txt && rm "$tmp/repo/leak.txt"
(cd "$tmp/repo" && ./.githooks/secret-scan --tracked > /dev/null 2>&1) || fail "clean repo failed the scan"

# --- secret-scan: newer providers, and output never re-leaks the value ---------
# Fixture values are assembled at runtime so no scanner (ours or a forge's)
# ever sees a contiguous credential-shaped literal in this file.
printf 'g=%s\ns=%s\n' "AIzaSyA$(printf '1234567890abcdefghijklmnopqrstuv')" \
  "sk_live_$(printf 'abcdefghijklmnopqrstuvwx')" > "$tmp/repo/leak2.txt"
(cd "$tmp/repo" && ./.githooks/secret-scan leak2.txt > /dev/null 2>&1) && fail "scan missed google/stripe-shaped keys"
out=$( (cd "$tmp/repo" && ./.githooks/secret-scan leak2.txt) 2>&1 || true)
echo "$out" | grep -q 'AIzaSyA1234567890' && fail "scan output re-leaked the secret value"
echo "$out" | grep -q 'redacted' || fail "scan did not report the redacted hit"
rm "$tmp/repo/leak2.txt"

# --- secret-scan: precision — placeholders and URL slugs never trip ------------
printf 'BOT=xoxb-your-bot-token\nURL=https://x.test/news/tradingview:c12b2e0666314:abcdefghijklmnopqrstuvwxyz0123456789abcd/\n' > "$tmp/repo/fp.txt"
(cd "$tmp/repo" && ./.githooks/secret-scan fp.txt > /dev/null 2>&1) || fail "scan flagged placeholder or URL-slug false positives"
rm "$tmp/repo/fp.txt"
printf 'a=%s\nb=%s\n' "123456789:$(printf 'AAbbCCddEEffGGhhIIjjKKllMMnnOOppQQrr')" \
  "xoxb-$(printf '123456789012-123456789012-abcdefghijklmnopqrstuvwx')" > "$tmp/repo/leak3.txt"
(cd "$tmp/repo" && ./.githooks/secret-scan leak3.txt > /dev/null 2>&1) && fail "scan missed real-shaped slack/telegram tokens"
rm "$tmp/repo/leak3.txt"

# --- pre-commit gate cache -----------------------------------------------------
# A scratch repo whose gate logs each run: two commits of the same tree must run
# the gate once; changing the tree must run it again; a worktree that diverges
# from the index must never be trusted as a cache hit.
printf 'check:\n\t@echo ran >> gate.log\n' > "$tmp/repo2/Makefile"
printf 'gate.log\n' > "$tmp/repo2/.gitignore"
printf 'v1\n' > "$tmp/repo2/f.txt"
git -C "$tmp/repo2" add Makefile .gitignore f.txt
(cd "$tmp/repo2" && ./.githooks/pre-commit > /dev/null 2>&1) || fail "gate-cache: first run failed"
[ "$(wc -l < "$tmp/repo2/gate.log")" -eq 1 ] || fail "gate-cache: first run did not run the gate"
(cd "$tmp/repo2" && ./.githooks/pre-commit > /dev/null 2>&1) || fail "gate-cache: cached run failed"
[ "$(wc -l < "$tmp/repo2/gate.log")" -eq 1 ] || fail "gate-cache: identical tree reran the gate"
printf 'v2\n' > "$tmp/repo2/f.txt"
git -C "$tmp/repo2" add f.txt
(cd "$tmp/repo2" && ./.githooks/pre-commit > /dev/null 2>&1) || fail "gate-cache: changed-tree run failed"
[ "$(wc -l < "$tmp/repo2/gate.log")" -eq 2 ] || fail "gate-cache: changed tree skipped the gate"
printf 'v3-unstaged\n' > "$tmp/repo2/f.txt"
(cd "$tmp/repo2" && ./.githooks/pre-commit > /dev/null 2>&1) || fail "gate-cache: dirty-worktree run failed"
[ "$(wc -l < "$tmp/repo2/gate.log")" -eq 3 ] || fail "gate-cache: dirty worktree was trusted as a cache hit"

# --- doctor: template drift classification ------------------------------------
# A locally extended secret-scan reads DIVERGED; a copy matching an older shipped
# template reads STALE (skipped when history is shallow or the template never changed).
echo '# local extension' >> "$tmp/repo/.githooks/secret-scan"
out=$(./doctor.sh "$tmp/repo") || fail "doctor errored on a diverged secret-scan"
echo "$out" | grep -q 'secret-scan diverged' || fail "doctor missed the diverged secret-scan"
first=$(git rev-list HEAD -- templates/AGENTS.md | tail -1)
if [ -n "$first" ] && ! git cat-file blob "$first:templates/AGENTS.md" 2>/dev/null | cmp -s - templates/AGENTS.md; then
  git cat-file blob "$first:templates/AGENTS.md" > "$tmp/repo/AGENTS.md"
  out=$(./doctor.sh "$tmp/repo") || fail "doctor errored on a stale AGENTS.md"
  echo "$out" | grep -q 'AGENTS.md is a stale template copy' || fail "doctor missed the stale AGENTS.md"
fi

echo "PASS  smoke: stamp, hooks, scanner, doctor, gate-cache"
