# Patterns

Shape-specific gold standards: reach for these when a repo has the shape, skip them when it doesn't.
Each was proven in one of the fleet's repos before landing here.
Unlike `templates/` stamped by `init.sh`, everything here is opt-in — the adopt skill (Phase 4) decides per repo.

## The verify skill — prove it runs, distinct from the gate

Every repo eventually needs "show me the change working in the real app," and it is not the test gate.
Copy `templates/skills/verify/SKILL.md` to `.claude/skills/verify/SKILL.md` and fill in the launch command, a worked end-to-end recipe, a negative probe, and the gotchas.
The negative probe matters most: a guard you never see reject anything might not be wired at all.

## The zone guard — ownership encoded in the directory tree

For repos where agents co-author durable state alongside code: declare which directories are tool-authored or human-owned, and block hand-edits mechanically.
Copy `templates/zones/guard_zones.py` to `.claude/hooks/` and `templates/zones/settings.json` to `.claude/settings.json`; configure `GUARDED_ZONES`, `ROOT_MARKERS`, and `MESSAGE` at the top.
Document the zone table in CLAUDE.md — ownership lives in the tree, the guard just enforces it.

## Billable tests behind a marker

Tests that hit paid or external services live behind an explicit pytest marker, excluded by default (`-m "not live"`, `--strict-markers`), so the full suite runs fearlessly locally and in CI.
`templates/python/pytest.ini` is the config — but it is not auto-installed: pytest.ini silently overrides `[tool.pytest]` in pyproject.toml, so add it only where no pytest config exists yet.

## The doctor verb

Three repos independently invented a read-only invariant checker — that convergence is the signal.
When a repo has structural invariants beyond what lint/types express (manifest conformance, zone drift, dangling references, wiring that must exist), give it a `make doctor`: read-only, PASS/WARN/FAIL per check, reports for a human, never auto-fixes.
Run it at session start; this repo's own `doctor.sh` is the reference shape.

## Status taxonomy for agent-facing tools

A tool an agent consumes should classify its failures instead of leaking tracebacks: `ok` (payload is the result), `transient` (upstream blip — wait `retry_after` seconds and retry), `permanent` (bad input or collision — fix the input, do not retry).
The classification lives at the network edge in one place, and every caller acts systematically instead of parsing error text.

## Runbooks with thin shims

When a repo has recurring operational sessions, the playbook lives once as a runbook file, and each `.claude/commands/*` slash command is a thin shim that loads and executes it.
Interactive and headless/scheduled runs stay in lockstep because neither duplicates the steps.
