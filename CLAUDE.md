# standards — canonical cross-project DX conventions

This repo is **agent-forward**: it gets added to sessions (`/add-dir`) so an
agent can drive repo housekeeping. Conventions flow in both directions:

- **Outbound** — the user asks to standardize, audit, adopt, or "run the
  standard" on a repo, or asks what a repo is missing: run `./doctor.sh <repo>`
  (read-only conformance report, drift checks, commit-history histogram), then
  follow `.claude/skills/adopt/SKILL.md` (`/adopt <repo>`) — classify → survey →
  configure → stamp → integrate → verify → commit → report. The classification
  gate (machine-written repos, forks, opt-outs) is not skippable.
  `./init.sh [-t types] [-s scopes] [-l python|node|none] [-c] <repo>` is the
  mechanical stamp; install-if-missing only.
- **Inbound** — the user attaches a repo to learn from it, or asks to ingest or
  harvest its practices: follow `.claude/skills/harvest/SKILL.md`
  (`/harvest <repo>`) — survey the surplus beyond the standard, verify each
  candidate actually works, classify it to a destination, propose before
  landing, then land one commit per change and offer the fleet sync.
- **Greenfield** — the user asks to spin up a new app: follow
  `.claude/skills/spinup/SKILL.md` (`/spinup <blueprint> <path>`), which
  executes `blueprints/<name>/BLUEPRINT.md` verbatim — scaffold, stamp, verify
  end-to-end, first commit through the hooks.

`DECISIONS.md` is the tooling-verdict register (what supersedes what, why, and
the migration recipe); the doctor warns on superseded tooling, and `/adopt`
applies the migrations.

## Invariants

- `templates/githooks/commit-msg` is the single source of truth for the commit
  format; `templates/AGENTS.md` describes it but defers to the hook. Change them
  together in one commit.
- `init.sh` never overwrites an existing file in a target repo — only
  install-if-missing and drift reporting. `doctor.sh` never mutates a target at
  all. Keep both POSIX sh.
- Judgment stays in the skill, mechanics stay in the scripts: anything requiring
  reading a target's docs or history belongs in `adopt`, not in shell.
- CI templates run `make check` and nothing else; the gate is defined once, in
  the Makefile.
- The standards stand independently: no template, pattern, decision, or blueprint
  references a source repository (provenance lives in commit history and memory).
  No project names, no machine-specific paths, and every entry must justify
  itself on its own reasoning.

## Conventions

- Commit messages: `<type>: Title case ending with period.` with type ∈
  feat|fix|chore|clean|revert (enforced by `.githooks/commit-msg`; this repo uses
  the scopeless form, and the hook rejects bodies).
  Subject line only — no body, no Co-Authored-By or other trailers.
  One logical change per commit. Commit locally and stop: pushing is the
  operator's review step.
- A playbook lesson learned in the field (a new fresh-checkout pitfall, a new
  skip category) belongs in `.claude/skills/adopt/SKILL.md` in the same commit
  as the change it motivated.
