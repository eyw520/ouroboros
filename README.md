# standards

Canonical DX conventions for every project: the commit format and its enforcing
hook, the CLAUDE.md / AGENTS.md structure, the `make check` gate, CI that runs
exactly the gate, and tooling baselines.

## Use

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
init.sh                      # stamp a repo / audit drift
```

## The convention, in one line

`<type>(<scope>): Title case ending with period.` — subject only, no trailers,
one logical change per commit, gate green before each, commit locally and stop:
pushing is the operator's review step.
