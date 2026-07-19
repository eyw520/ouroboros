# standards

Canonical DX conventions for every project: the commit format and its enforcing
hook, the CLAUDE.md / AGENTS.md structure, the `make check` gate, CI that runs
exactly the gate, and tooling baselines.

## Agent-forward use (the intended path)

Add this repo to a Claude Code session (`/add-dir path/to/standards`) and ask it
to standardize or audit a repo — its CLAUDE.md routes the agent to `doctor.sh`
(read-only audit) and the `adopt` skill (`/adopt <repo>`), which carries the
full playbook: classification, config-from-history, doc integration, gate
verification, and the fresh-checkout pitfalls that break first CI runs.

The reverse direction works too: attach a repo worth learning from and ask to
harvest it — the `harvest` skill (`/harvest <repo>`) surveys what the repo does
beyond the standard, verifies each practice actually works, and ports the
accepted ones into templates, doctor checks, AGENTS.md, or PATTERNS.md, with
provenance and a fleet sync.

```sh
./doctor.sh ../myproject     # what's missing / drifted, and suggested -t/-s
```

## Manual use

```sh
./init.sh -s "all|agent|infra" -l python -c ../myproject
```

- Copies templates that are missing; never overwrites. Rerun any time to audit —
  files that drifted from the template report `DIFFERS`.
- Renders the `-t`/`-s` values into `.githooks/commit-msg` and wires
  `core.hooksPath` in the target so the hook is live immediately.

Flags: `-t types` (default `feat|fix|chore|clean|revert`), `-s scopes` (default
empty, meaning the scopeless `<type>: ...` form), `-l python|node|none`, `-c`
to install the CI gate workflow.

## Layout

```
templates/
  AGENTS.md                  # shared conventions, imported by every CLAUDE.md
  CLAUDE.md                  # thin project skeleton: Overview / Layout / Invariants / Conventions / Gotchas
  githooks/commit-msg        # parameterized commit-message gate (types/scopes vars at top)
  editorconfig               # installed as .editorconfig
  github/workflows/gate.yml  # CI = `make check`, nothing else
  python/                    # Makefile + ruff.toml + mypy.ini + pyrightconfig.json (uv, py311, line 120)
  node/                      # Makefile mapping the same verbs onto npm scripts
  skills/verify/             # "prove it runs" skill skeleton (opt-in, see PATTERNS.md)
  zones/                     # PreToolUse zone guard for agent-co-authored repos (opt-in)
init.sh                      # stamp a repo / audit drift (install-if-missing, never overwrites)
doctor.sh                    # read-only conformance audit + config suggestion
PATTERNS.md                  # shape-specific gold standards, applied per repo by /adopt
.claude/skills/adopt/        # outbound: the adoption playbook, /adopt <repo>
.claude/skills/harvest/      # inbound: ingest a repo's practices, /harvest <repo>
```

## The convention, in one line

`<type>(<scope>): Title case ending with period.` — subject only, no trailers,
one logical change per commit, gate green before each, commit locally and stop:
pushing is the operator's review step.
