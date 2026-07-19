# standards — canonical cross-project DX conventions

Templates live in `templates/`; `init.sh` stamps them into a target repo and,
rerun later, audits drift. Editing a template edits every future consumer —
keep templates generic (no project names, no machine-specific paths).

## Invariants

- `templates/githooks/commit-msg` is the single source of truth for the commit
  format; `templates/AGENTS.md` describes it but defers to the hook. Change them
  together in one commit.
- `init.sh` never overwrites an existing file in a target repo — only install-if-missing
  and drift reporting. Keep it POSIX sh.
- CI templates run `make check` and nothing else; the gate is defined once, in the Makefile.

## Conventions

- Commit messages: `<type>: Title case ending with period.` with type ∈
  feat|fix|chore|clean|revert (enforced by `.githooks/commit-msg`; this repo uses
  the scopeless form).
  Subject line only — no body, no Co-Authored-By or other trailers.
  One logical change per commit. Commit locally and stop: pushing is the
  operator's review step.
