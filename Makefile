# Dev workflow. `make dev` once after cloning; `make check` before every commit.
.PHONY: check lint test hooks dev

# The gate: static analysis over every script, then the smoke suite.
check: lint test

lint:
	shellcheck init.sh doctor.sh tests/smoke.sh \
		templates/githooks/commit-msg templates/githooks/pre-commit templates/githooks/secret-scan \
		.githooks/commit-msg .githooks/pre-commit .githooks/secret-scan

test:
	./tests/smoke.sh

hooks:
	git config core.hooksPath .githooks

dev: hooks
