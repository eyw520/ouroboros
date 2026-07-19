# Dev workflow. `make dev` once after cloning; `make check` before every commit.
.PHONY: check lint types test fmt hooks dev

# The gate — run all of it before declaring work done.
check: types lint test

lint:
	npm run lint
	npm run format:check

types:
	npm run typecheck

test:
	npm test

# Auto-fix what the gate would flag: style, formatting.
fmt:
	npm run format

# Wire the repo's commit-message hook (dormant until core.hooksPath points at it).
# Node repos may prefer the npm `prepare` script: "prepare": "git config core.hooksPath .githooks"
hooks:
	git config core.hooksPath .githooks

# One-shot setup for a fresh clone: dependencies plus the commit hook.
dev: hooks
	npm install
