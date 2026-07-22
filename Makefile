# Dev workflow. `make dev` once after cloning; `make check` before every commit.
.PHONY: check lint test hooks skill dev

# The gate: static analysis over every script, then the smoke suite.
check: lint test

lint:
	shellcheck init.sh doctor.sh fleet.sh tests/smoke.sh \
		templates/githooks/commit-msg templates/githooks/pre-commit \
		templates/githooks/pre-commit-scoped templates/githooks/secret-scan \
		.githooks/commit-msg .githooks/pre-commit .githooks/secret-scan

test:
	./tests/smoke.sh

hooks:
	git config core.hooksPath .githooks

# Symlink the seed skill user-level so any repo on this machine can run /seed.
skill:
	mkdir -p "$(HOME)/.claude/skills"
	ln -sfn "$(CURDIR)/.claude/skills/seed" "$(HOME)/.claude/skills/seed"

dev: hooks skill
