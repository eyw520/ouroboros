# standards

Canonical engineering conventions, templates, and stack blueprints — agent-forward by design.
Add this repo to a Claude Code session (`/add-dir`) and ask it to standardize, audit, harvest, or spin up; `CLAUDE.md` routes the agent from there.

- `/adopt <repo>` — push the standard into a repo (`init.sh` stamps, `doctor.sh` audits).
- `/harvest <repo>` — ingest a repo's best practices into the standard.
- `/spinup <blueprint> <path>` — create a new app from `blueprints/`, born conforming.

Manual entry points: `./doctor.sh <repo>` (read-only audit) and `./init.sh [-t types] [-s scopes] [-l python|node] [-c] <repo>` (install-if-missing stamp).
Reference: `PATTERNS.md` (opt-in, shape-specific), `DECISIONS.md` (tooling verdicts + migration recipes), `templates/` (the stamped files).
The convention in one line: `<type>(<scope>): Title case ending with period.` — subject only, one logical change per commit, gate green before each, commit locally and stop.
