# ouroboros — canonical cross-project engineering conventions

Agent-forward: this repo is added to sessions so an agent can drive repo housekeeping.
Route by request:

- **Standardize/audit a repo** → `./doctor.sh <repo>`, then the `adopt` skill (`/adopt <repo>`).
  `./init.sh [-t types] [-s scopes] [-l python|node|none] [-c] <repo>` is the mechanical stamp (install-if-missing only).
- **Seed from inside a target repo** → the `seed` skill (`/seed`), symlinked user-level by `make skill`; it locates this checkout through the symlink and runs adopt against the cwd.
- **Learn from / ingest a repo** → the `harvest` skill (`/harvest <repo>`).
- **Spin up a new app** → the `spinup` skill (`/spinup <blueprint> <path>`), executing `blueprints/<name>/BLUEPRINT.md` verbatim.
- **Audit or sync the fleet** → `./fleet.sh` (read-only doctor sweep, one line per repo); `./fleet.sh stamp` re-stamps stale template copies, never diverged ones, never commits.
  The repo list is the gitignored `fleet.txt` (machine-local by the independence invariant), else sibling-directory discovery.

`DECISIONS.md` registers tooling verdicts with migration recipes; the doctor warns on superseded tooling.
`PATTERNS.md` holds opt-in, shape-specific patterns.

## Invariants

- The founding thesis: only enforced or mechanized conventions survive — prose-only rules drift.
  Every addition should make something checkable (doctor), enforced (hooks/CI), or executable (scripts/recipes); prose that cannot become one of those is a smell.
- `templates/githooks/commit-msg` is the single source of truth for the commit format; docs defer to it. Change hook and docs together.
- `init.sh` never overwrites; `doctor.sh` never mutates. Both stay POSIX sh.
- Judgment lives in the skills, mechanics in the scripts.
- CI runs `make check` and nothing else.
- The standards stand independently: no template, pattern, decision, or blueprint references a source repository (provenance lives in commit history and memory); no project names, no machine-specific paths; every entry justifies itself on its own reasoning.
- The mirror of that independence: stamped repos never learn this repo exists — nothing under `templates/` names ouroboros, its scripts or docs, or a version marker; staleness is judged by the doctor against template history here, never recorded in the target.
- A field lesson lands in the skill it improves, in the same commit as the change that motivated it.

## Conventions

- Commit messages: `<type>: Sentence case ending with period.`, type ∈ feat|fix|chore|clean|revert (enforced by `.githooks/commit-msg`; scopeless, body-rejecting, cosmetic-auto-fixing).
  Subject only — no trailers. One logical change per commit; gate green before each (enforced by pre-commit). Commit locally and stop: pushing is the operator's review step.
- Prose is one sentence per line; keep every file as lean as its job allows — these files are loaded into agent context.
  The always-loaded docs (CLAUDE.md + its `@`-imports) carry a line budget the doctor checks; runaway context is a WARN, not a matter of taste.
