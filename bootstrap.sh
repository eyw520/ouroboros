#!/bin/sh
# Put the standards checkout on this machine and wire its skills user-level, so
# every repo can run /seed (and adopt/harvest/spinup) with no per-session setup.
#
#   ./bootstrap.sh              from inside a checkout: just wire the skills
#   sh bootstrap.sh [dir] [url] fresh machine: clone into dir, then wire
#     dir  where to clone when no checkout is found  (default: $HOME/.ouroboros)
#     url  remote to clone from                      (default: $OURO_REMOTE)
# Idempotent: an existing checkout is reused, the symlinks are refreshed in place.
set -e

self=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

# A directory is a checkout if it carries the pieces `make skill` needs to wire.
is_checkout() { [ -f "$1/Makefile" ] && [ -d "$1/templates" ] && [ -d "$1/.claude/skills/seed" ]; }

if is_checkout "$self"; then
  root=$self
else
  root=${1:-$HOME/.ouroboros}
  if is_checkout "$root"; then
    :
  elif [ -e "$root" ]; then
    echo "ERROR: $root exists but is not an ouroboros checkout." >&2
    exit 1
  else
    url=${2:-$OURO_REMOTE}
    [ -n "$url" ] || { echo "ERROR: no checkout found and no remote given (pass a URL or set OURO_REMOTE)." >&2; exit 1; }
    echo "cloning $url -> $root"
    git clone -q "$url" "$root"
  fi
fi

make -C "$root" skill
echo "bootstrapped: $root (skills wired user-level; run /seed from any repo)"
