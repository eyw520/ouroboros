---
name: spinup
description: Create a new application from a blueprint — scaffold, stamp governance, verify it runs end-to-end, first commit. Use when asked to spin up, bootstrap, or start a new app or project.
argument-hint: <blueprint> <path-for-new-repo>
---

You are creating a new repo from `blueprints/<name>/BLUEPRINT.md`.
The blueprint is the instructions — follow it verbatim; do not improvise structure.
If no blueprint fits the request, say so and offer `/harvest` on a reference project to create one.

**Locate the standards checkout** (blueprints, `init.sh`, `doctor.sh` live in it): the repo added to this session, or — when run ambient via the user-level skill symlink — `readlink ~/.claude/skills/spinup`, root three directories up.
Neither resolves → run the checkout's `bootstrap.sh` to (re)wire the kit, or ask for the path; never guess.

## Phase 0 — Inputs

Confirm the app name, target path, and any decision the blueprint marks as a real choice (e.g. deploy target).
Everything else is prescribed; do not re-litigate the blueprint's recorded decisions.

## Phase 1 — Scaffold

`git init` the target, then execute the blueprint's scaffold recipe in order.
Generator commands (create-next-app etc.) run with exactly the pinned flags; a deliberate flag change is a blueprint edit first (via `/harvest` discipline), not a local deviation.

## Phase 2 — Stamp governance

Run `init.sh` with the blueprint's stated flags, then reconcile any `DIFFERS` in the blueprint's favor where it says so.
Wire `make dev`; the repo must be born conforming: run `doctor.sh` and drive it to zero FAIL before proceeding.

## Phase 3 — Verify end-to-end

Execute the blueprint's Verify section literally — launch the real services, hit the real endpoints, run the sync, include the negative probe.
A scaffold that lints but does not run is not done; do not commit until verify passes.

## Phase 4 — First commit (and optional publish)

One commit through the new hooks: `feat: Spin up <name> from the <blueprint> blueprint.`
If asked to publish: `gh repo create` (private unless told otherwise), push, and watch the first CI gate to green — fix-forward, never skip.

## Phase 5 — Record

Seed the new repo's CLAUDE.md from the blueprint's Decisions and Gotchas (audience split: README for humans).
Report what was built, what verify proved, and anything the blueprint got wrong — then fold that correction into the blueprint in the ouroboros repo, same commit discipline as any harvest.
