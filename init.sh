#!/bin/sh
# Stamp the standard conventions into a target repo, or rerun to audit drift.
# Copies only files that are missing; existing files are never overwritten —
# a rerun reports DIFFERS for anything that drifted from the template.
set -e

usage() {
  echo "Usage: init.sh [-t types] [-s scopes] [-l python|node|none] [-c] <target-repo>"
  echo "  -t  pipe-separated commit types   (default: feat|fix|chore|clean|revert)"
  echo "  -s  pipe-separated commit scopes  (default: empty = scopeless '<type>: ...')"
  echo "  -l  language preset for Makefile and tool configs (default: none)"
  echo "  -c  install the CI gate workflow (.github/workflows/gate.yml)"
  exit 1
}

std_root=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
tpl="$std_root/templates"

types="feat|fix|chore|clean|revert"
scopes=""
lang="none"
ci=0

while getopts "t:s:l:c" opt; do
  case $opt in
    t) types="$OPTARG" ;;
    s) scopes="$OPTARG" ;;
    l) lang="$OPTARG" ;;
    c) ci=1 ;;
    *) usage ;;
  esac
done
shift $((OPTIND - 1))

# The values are spliced into the hook via sed: anything outside this whitelist
# (',' '&' '\' regex metacharacters) would silently corrupt the generated hook.
case "$types|$scopes" in
  *[!A-Za-z0-9_|-]*)
    echo "ERROR: -t/-s accept only letters, digits, '_', '-', and '|'."
    exit 1 ;;
esac

target="$1"
[ -n "$target" ] || usage
[ -d "$target/.git" ] || { echo "ERROR: $target is not a git repository."; exit 1; }

install() {
  src="$1"; rel="$2"; dst="$target/$rel"
  mkdir -p "$(dirname "$dst")"
  if [ ! -f "$dst" ]; then
    cp "$src" "$dst"
    echo "installed  $rel"
  elif cmp -s "$src" "$dst"; then
    echo "up-to-date $rel"
  else
    echo "DIFFERS    $rel (left untouched; compare: diff \"$src\" \"$dst\")"
  fi
}

hook_tmp=$(mktemp)
sed -e "s,^types=.*,types=\"$types\"," \
    -e "s,^scopes=.*,scopes=\"$scopes\"," \
    "$tpl/githooks/commit-msg" > "$hook_tmp"
install "$hook_tmp" ".githooks/commit-msg"
chmod +x "$target/.githooks/commit-msg"
rm -f "$hook_tmp"

install "$tpl/githooks/pre-commit" ".githooks/pre-commit"
install "$tpl/githooks/secret-scan" ".githooks/secret-scan"
chmod +x "$target/.githooks/pre-commit" "$target/.githooks/secret-scan"

install "$tpl/AGENTS.md" "AGENTS.md"
install "$tpl/CLAUDE.md" "CLAUDE.md"
install "$tpl/editorconfig" ".editorconfig"

case "$lang" in
  python)
    install "$tpl/python/python-version" ".python-version"
    install "$tpl/python/Makefile" "Makefile"
    install "$tpl/python/ruff.toml" "ruff.toml"
    install "$tpl/python/mypy.ini" "mypy.ini"
    install "$tpl/python/pyrightconfig.json" "pyrightconfig.json"
    ;;
  node)
    install "$tpl/node/Makefile" "Makefile"
    ;;
  none) ;;
  *) echo "ERROR: unknown language preset '$lang'."; usage ;;
esac

if [ "$ci" = 1 ]; then
  install "$tpl/github/workflows/gate.yml" ".github/workflows/gate.yml"
fi

git -C "$target" config core.hooksPath .githooks
echo "wired      core.hooksPath = .githooks"
