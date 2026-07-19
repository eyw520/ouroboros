# Decisions

The tooling verdicts behind the templates: what the standard prescribes, why, and how to migrate a repo that predates the verdict.
`doctor.sh` warns on superseded tooling; `/adopt` applies migrations; `/harvest` records a new verdict when a better convention proves out in the wild.
One entry per verdict, newest first — a verdict without a migration recipe is not done.

## uv over poetry (2026-07-19)

Verdict: Python dependency management is `uv`; `poetry` is superseded.
Why: order-of-magnitude faster installs (CI minutes become seconds), one binary with no bootstrap step (the `pipx install poetry` CI dance disappears), `.python-version` honored natively by `uv python install`, and lockfile freshness is one read-only flag (`uv lock --check`).
The templates already assume it (`templates/python/Makefile`, the CI gate).
Migrate:
1. `uvx migrate-to-uv` in the repo root converts the poetry sections of `pyproject.toml` and writes `uv.lock` (manual fallback: rewrite `[tool.poetry]` as PEP 621 `[project]`, then `uv lock`).
2. Swap Makefile verbs from `poetry run` to `uv run`; `dev` becomes `hooks` + `uv sync`.
3. CI: drop `pipx install poetry` and `cache: poetry`; use `astral-sh/setup-uv` with `enable-cache: true`, then `uv python install` and `uv sync --frozen`.
4. Run the full gate before and after; delete `poetry.lock` (and `poetry.toml`) only once green.
Fleet status: infiniclaw, datagate, alexandria already uv; infinitron, autolab, constellation still poetry.

## Committed .githooks over husky (2026-07-19)

Verdict: git hooks live in a committed `.githooks/` wired via `core.hooksPath`, never husky.
Why: zero dependencies, works in non-node repos, no package.json coupling, and the hooks are plain scripts the doctor can parse and replay (`types=`/`scopes=` are machine-readable).
Migrate: install the canonical hooks (`init.sh` or `/adopt`), port any custom hook logic into them, wire `core.hooksPath .githooks` (the `hooks` make verb), then delete `.husky/`, the husky dependency, and its `prepare` script.
