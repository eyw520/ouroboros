# Dev workflow. `make dev` once after cloning; `make check` before every commit.
.PHONY: check lint test hooks skill dev

# The gate: static analysis over every script, then the smoke suite.
check: lint test

lint:
	shellcheck init.sh doctor.sh fleet.sh bootstrap.sh tests/smoke.sh \
		templates/githooks/commit-msg templates/githooks/pre-commit \
		templates/githooks/pre-commit-scoped templates/githooks/secret-scan \
		.githooks/commit-msg .githooks/pre-commit .githooks/secret-scan

test:
	./tests/smoke.sh

hooks:
	git config core.hooksPath .githooks

# Wire the whole kit user-level so any repo can run /seed (and adopt/harvest/
# spinup), each self-locating this checkout through its own symlink.
skill:
	mkdir -p "$(HOME)/.claude/skills"
	for s in seed adopt harvest spinup; do \
		ln -sfn "$(CURDIR)/.claude/skills/$$s" "$(HOME)/.claude/skills/$$s"; \
	done

dev: hooks skill
