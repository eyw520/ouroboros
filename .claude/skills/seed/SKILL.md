---
name: seed
description: Seed the shared engineering standards into the current repo — fresh or existing — by locating the standards checkout and driving the adopt flow against the cwd. Use when asked to seed, standardize, or adopt the standards from inside a target repo, without the standards repo added to the session.
---

You are inside the *target* repo; the standards checkout lives elsewhere on this machine.
This skill only locates the two repos and hands off — the judgment lives in the adopt skill.

## Locate

1. Standards checkout: the ouroboros repo added to this session if present, else `readlink ~/.claude/skills/seed` — the checkout root is three directories up (the link points at `<root>/.claude/skills/seed`).
   Neither resolves (fresh machine, dangling link) → run the checkout's `bootstrap.sh` to (re)wire the kit, or ask the user where the checkout lives. Never guess.
2. Target: `git rev-parse --show-toplevel` from the cwd.
   Not a git repo yet → confirm with the user, then `git init`; it proceeds as greenfield.
   Target resolves to the standards checkout itself → stop and say so; it is worked on directly, not seeded.

## Hand off

Read `<standards>/.claude/skills/adopt/SKILL.md` and execute it phase by phase with `<target>` = this repo.
Run the classification gate even though the user invoked the skill deliberately — deliberate invocation on a fork or an opted-out repo is still a decline.

Greenfield additions on top of adopt:

- No history and no docs leave nothing to derive config from: ask the user for the language preset and whether scopes are wanted (default scopeless) instead of inventing them.
- No commits yet → the adoption stamp becomes the repo's first commit, made through the freshly wired hooks.

## Invariant

Write nothing into the target that names the standards repo or its scripts — the stamp is source-blind.
Report exactly as adopt prescribes: drift repaired, debts left, security flags.
