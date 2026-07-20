# Patterns

Shape-specific gold standards: reach for these when a repo has the shape, skip them when it doesn't.
Every entry carries its applicability contract: the shape that triggers it, the counter-indication (mandatory — a pattern without a "when not" is a mandate in disguise), the mechanics, and the proof that it is working.
Every entry stands on its own reasoning — no entry cites where it came from, because a pattern that needs its lineage to justify itself is not a standard.
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

Tests that hit paid, external, or infrastructure-dependent services live behind an explicit pytest marker, excluded by default (`-m "not live"`, `-m "not integration"`, `--strict-markers`), so the full suite runs fearlessly locally and in CI.
`templates/python/pytest.ini` is the config — but it is not auto-installed: pytest.ini silently overrides `[tool.pytest]` in pyproject.toml, so add it only where no pytest config exists yet.

## The doctor verb

Lint and types cannot see structural invariants, so repos that have them keep reinventing a read-only checker — make it a named verb instead.
When a repo has structural invariants beyond what lint/types express (manifest conformance, zone drift, dangling references, wiring that must exist), give it a `make doctor`: read-only, PASS/WARN/FAIL per check, reports for a human, never auto-fixes.
Run it at session start; this repo's own `doctor.sh` is the reference shape.
A second axis: the ENVIRONMENT doctor — check the machine, not the repo.
Before conformance, verify the required toolchain is present and at the pinned versions (node against `.nvmrc`, python against `.python-version`, the package managers themselves), so `make dev`'s silent assumptions become checkable and a fresh machine fails loudly instead of half-working.

## Status taxonomy for agent-facing tools

A tool an agent consumes should classify its failures instead of leaking tracebacks: `ok` (payload is the result), `transient` (upstream blip — wait `retry_after` seconds and retry), `permanent` (bad input or collision — fix the input, do not retry).
The classification lives at the network edge in one place, and every caller acts systematically instead of parsing error text.
When errors cross a text-only boundary, the classified error renders its status, retry delay, and detail as trailing `key=value` pairs in its own message, so even a client that only sees error strings keeps the machine-readable verdict.
Base the classified error type on the language's generic runtime error so existing catch sites keep working — adoption should not require touching every caller.

## Scoped gates for slow monorepos

When a multi-toolchain monorepo's full gate is too slow for every commit, scope the pre-commit instead of abandoning it: detect which areas the staged paths touch, run only the relevant legs, parallelize independent legs within phases (fast lint before slow typecheck), and print per-leg timings with a slowest-leg callout so gate cost stays visible and attributable.
`templates/githooks/pre-commit-scoped` is the generic harness — the filters and job lists are per-repo config at the top; the timing and job machinery is reusable.
CI still runs the full gate: scoping trades a little local coverage for speed, never CI coverage.
A typical shape is three phases — lint, typecheck, generated-artifact refresh — across two toolchains.

## Fast gates for slow suites

When the test leg dominates a gate that runs per commit, two opt-in accelerators exist beyond the standard caches; both trade a little trust for a lot of time, so keep CI running the full uncached gate either way.
Both are candidates, not verdicts: trial one against the repo's own suite and promote it to DECISIONS.md only once it proves out.
`pytest-testmon` runs only the tests whose covered code changed — right for suites in the minutes, wrong for suites already under a minute (overhead eats the win).
`dmypy` (the mypy daemon) makes warm typechecks near-instant, but misbehaves with some plugin-heavy configs — verify against the repo's plugins before adopting.
The gate-result cache in the pre-commit hook already makes identical-tree reruns free; these are for when the tree genuinely changed.

## Parallel test suites

When the test leg dominates the gate and tests are mostly independent, run them across cores: `pytest -n auto --dist loadgroup` via `pytest-xdist` (jest/vitest parallelize by default — check they have not been forced serial).
Skip when the suite is already fast — worker startup costs seconds, so a sub-30s suite can get slower — or when tests share mutable state you cannot isolate or group.
Shared-state tests are grouped, not abandoned: a module-level `pytestmark = pytest.mark.xdist_group("<resource>")` pins every test touching one resource (a message bus, a rate limiter, a database) to a single worker while the rest of the suite fans out; `--dist loadgroup` is what honors the groups.
Register `xdist_group(name)` in the markers list (with `--strict-markers`) so a typo'd group fails loudly instead of silently degrouping.
Resist adding a separate serial lane: grouping makes "cannot parallelize" a per-resource property instead of a suite property, so one command still runs everything.
Proof: a `--durations=0` variant target names the slow tests; the parallel and serial runs must report identical pass/skip counts (a diverging count is a hidden ordering dependency), and a CPU-bound suite in the minutes should drop to tens of seconds on laptop-class cores.
Composes with the other gate accelerators — the tree-hash cache (free), testmon (run less), this (run wider), dmypy (stay warm) — they stack.

## The env contract

A service-shaped repo declares its configuration as a committed `.env.example` documenting every variable; the real env file is gitignored, and the secret scan keeps it that way.
A monorepo enters configuration once: `make setup-env` fans per-package env files out of the one root `.env`, so no package's requirements live only in a teammate's shell history.
Variants for different shapes: a root example with generated fan-out, per-unit env examples, or a gitignored secrets file holding references resolved only at point of use.

## Generated artifacts are never hand-edited

An artifact derived from source (an OpenAPI spec, an SDK, a JSON Schema snapshot) is regenerated, never edited — and the hook that detects the drift does the regenerating: when the generating sources change, pre-commit rebuilds the artifact and, if it drifted, stages the regenerated result to ride the same commit.
Pair it with a First-Principles line forbidding manual edits to the generated paths, so the rule is stated where agents read and enforced where commits happen.
Examples of the shape: schema snapshots with a regen target riding the causing commit; OpenAPI/SDK regeneration auto-staged in pre-commit.

## Runbooks with thin shims

When a repo has recurring operational sessions, the playbook lives once as a runbook file, and each `.claude/commands/*` slash command is a thin shim that loads and executes it.
Interactive and headless/scheduled runs stay in lockstep because neither duplicates the steps.

## Fencing a generic API tool for agents

A tool that accepts arbitrary upstream method names hands the agent the whole provider API — which is the point — so the safety lives in the transport layer, not in curating the tool list.
Four fences, enforced in one shared place: credentials enter only through the environment (any credential-named key in a payload is rejected, recursively); credential-shaped strings are redacted from every response, including echo-style methods, so the model never sees a token; outbound requests are HTTPS-only against an allowlisted host set, re-validated on every redirect hop, because a compliant first URL can 302 anywhere; downloads are byte-capped.
Annotation honesty is part of the fence: a generic tool that can invoke write methods is never annotated read-only — paginated variants included, because a cursor loop over a write method is still a write, and clients skip confirmation for tools that claim read-only.

## The self-describing tool surface

An agent-facing API server teaches the agent how to use it: a capabilities resource enumerating the surface, a method-docs tool mapping any upstream method name to its official documentation URL and the generic call shape to use, and the provider's canonical doc URLs exposed as a resource.
Pair curated helpers for the common workflows with a generic passthrough for everything else: the curated tools carry the ergonomics, and the passthrough plus method-docs means a new provider capability costs zero server code — the alternative is a tool-per-method treadmill that never ends.

## Declarative credential routing

When a provider requires different credentials for different methods (search wants the user identity, write families want the bot identity), the who-needs-what table is config, not control flow: a rule list mapping method prefixes and exact names to a credential kind, resolved per call, falling back to the default credential when the preferred kind is not configured.
Callers can still pin a kind explicitly; an unknown kind fails fast listing the allowed set, so the taxonomy of identities stays discoverable from the error itself.

## Responses sized for the model

Oversized payloads never fail loudly — they silently crowd out the agent's context, or the vision pipeline drops the image and the agent sees "could not be processed".
Three disciplines for a server that feeds a model: raw upstream payloads are opt-in, never the default, because they roughly double every read; aggregate reads (threads, histories, paginated collections) pass through a byte budget that truncates long string leaves with visible markers — never keys, never structure — so the agent knows data was cut and can re-fetch narrower; images are pre-shrunk to the vision pipeline's limits (long edge and base64 byte ceiling) before crossing the wire.
Deliberate byte transfers such as file downloads bypass the budget — they are explicitly sized by their own cap already.
Truncation is always reported, in-band or as a flag: a silent cap reads as "covered everything" when it didn't.
