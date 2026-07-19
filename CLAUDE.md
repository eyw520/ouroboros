# standards — canonical cross-project DX conventions

This repo is **agent-forward**: it gets added to sessions (`/add-dir`) so an
agent can drive repo housekeeping. If the user asks to standardize, audit,
adopt, or "run the standard" on any repo — or asks what a repo is missing:

1. `./doctor.sh <repo>` — read-only conformance report, drift checks, and a
   commit-history histogram to derive types/scopes from.
2. Follow `.claude/skills/adopt/SKILL.md` (invocable as `/adopt <repo>`) — the
   full playbook: classify → survey → configure → stamp → integrate → verify →
   commit → report. The classification gate (machine-written repos, forks,
   opt-outs) is not skippable.
3. `./init.sh [-t types] [-s scopes] [-l python|node|none] [-c] <repo>` — the
   mechanical stamp; install-if-missing only.

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
- Keep templates generic — no project names, no machine-specific paths.

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
