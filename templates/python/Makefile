# Dev workflow. `make dev` once after cloning; `make check` before every commit.
# ruff and mypy cache incrementally by default (.ruff_cache/.mypy_cache —
# gitignore them, never disable them): a warm no-change gate should cost seconds.
.PHONY: check lint types test fmt hooks dev

# The gate — run all of it before declaring work done.
check: lint types test

lint:
	uv run ruff check .
	uv run ruff format --check .

types:
	uv run mypy .

test:
	uv run pytest -q

# Auto-fix what the gate would flag: import order, style, formatting.
fmt:
	uv run ruff check . --fix
	uv run ruff format .

# Wire the repo's commit-message hook (dormant until core.hooksPath points at it).
hooks:
	git config core.hooksPath .githooks

# One-shot setup for a fresh clone: dependencies plus the commit hook.
dev: hooks
	uv sync
