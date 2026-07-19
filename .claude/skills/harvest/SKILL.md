---
name: harvest
description: Learn from a repo and port its best practices into the standards — survey, verify, classify, propose, land. Use when asked to ingest, harvest, or learn from a repository, or "what can we learn from X".
argument-hint: <path-to-source-repo>
---

You are mining a source repo for practices worth folding into the standard.
This is the inverse of `adopt`: the doctor reports where a repo falls SHORT of the standard; harvest looks for where it EXCEEDS it.
Work phase by phase; a change to the standard reaches every repo, so the bar is higher than for an adoption.

## Phase 0 — What counts

Harvestable: enforcement inventions (hooks, guards, scanners, CI mechanics), gate/caching mechanics, checkable invariants, convention wordings, doc structures, shape-specific patterns.
A sharper WORDING of an existing rule is a valid harvest — upgrade the standard's phrasing in place.
Not harvestable: domain machinery, a fork's upstream conventions, aspirational config that nothing actually uses, and deliberate divergences (a repo that consciously contradicts the standard is expressing a policy, not a defect — at most note it as a known alternative).

## Phase 1 — Survey for the surplus

1. `<standards>/doctor.sh <repo>` — the conformance baseline; ignore the gaps, note what it can't see.
2. Read what ENFORCES: hooks, CI workflows, Makefile targets, tool configs, `.claude/` hooks and skills, test-suite structure.
3. Read what DOCUMENTS: CLAUDE.md/AGENTS.md sections the standard lacks — invariants-with-reasons, gotchas, principles.
4. Diff mentally against `templates/`, `AGENTS.md`, `PATTERNS.md`, `doctor.sh`: anything present here already is not a finding.

## Phase 2 — Verify each candidate is real

Prose drifts; only what is enforced or exercised counts as proven.
For each candidate, confirm it actually works before proposing it: fire the hook, run the scanner, check the config applies, check history complies.
Read command output carefully and re-run rather than infer — a misread of which command produced which output can fabricate a finding (or a false alarm).
Note each candidate's failure modes while you have the source in front of you; they become the template's comments.

## Phase 3 — Classify to a destination

- Enforced mechanism, universally applicable → `templates/` + an `init.sh` install line + a `doctor.sh` check + smoke coverage.
- Checkable invariant → a `doctor.sh` check alone.
- Universal principle or better wording → `templates/AGENTS.md`. **Batch these**: every AGENTS.md edit costs a fleet re-sync, so land doc changes together, not dribbled.
- Shape-specific (only some repos have the shape) → `PATTERNS.md`, with provenance, plus a `templates/` asset if there is concrete code to copy.
- Tooling verdict (X supersedes Y) → `DECISIONS.md`, with the why and an executable migration recipe — a verdict without a recipe is not done.
- Stack-structure practice (how an app of this shape is laid out, deployed, wired) → the relevant `blueprints/*/BLUEPRINT.md`.
- Process lesson (how adoption or harvesting itself should work) → the `adopt` or `harvest` skill, in the same commit as the change that motivated it.
- Convergence test: independently invented in two or more repos → strong candidate; single-repo → needs an explicit story for why it generalizes.

## Phase 4 — Propose before landing

Present a harvest report: each candidate with its evidence, destination, and a tier (enforcement > writing conventions > shape patterns).
The operator picks; a standards change is fleet-wide policy, not a repo-local fix, so do not land unapproved candidates.

## Phase 5 — Land

One logical change per commit, gate green before each (this repo's pre-commit enforces it).
Generalize on the way in: strip project names and machine-specific paths from anything entering `templates/`; parameterize what varies (the config block at the top of a script is the pattern).
Every new mechanism gets smoke coverage; every new expectation gets a doctor check; a silent failure mode discovered during testing gets a loud guard.

## Phase 6 — Sync and record

If `templates/AGENTS.md` or a stamped template changed, offer the fleet re-sync (copy + one `chore: Sync ...` commit per repo, gates green).
Provenance lives in the harvest commit and in memory, never in the landed text: the standards stand independently, so no template, pattern, or decision cites a source repository — an entry that cannot justify itself on its own reasoning is not ready to land.
