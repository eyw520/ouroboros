# Ouroboros

Canonical engineering conventions, templates, and stack blueprints — agent-forward by design.
Wire the kit into a machine once with `make skill` (or the one-liner below) and the skills run ambient from any repo — each self-locates this checkout through its user-level symlink, so `/add-dir` is optional.

```sh
sh bootstrap.sh "$HOME/.ouroboros" https://github.com/eyw520/ouroboros.git   # fresh machine: clone + wire
```

- `/seed` — stamp the standard into the *current* repo, fresh or existing; the from-inside entry point, no arguments.
- `/adopt <repo>` — push the standard into another repo (`init.sh` stamps, `doctor.sh` audits).
- `/harvest <repo>` — ingest a repo's best practices into the standard.
- `/spinup <blueprint> <path>` — create a new app from `blueprints/`, born conforming.

Manual entry points: `./doctor.sh <repo>` (read-only audit) and `./init.sh [-t types] [-s scopes] [-l python|node] [-c] <repo>` (install-if-missing stamp).
Reference: `PATTERNS.md` (opt-in, shape-specific), `DECISIONS.md` (tooling verdicts + migration recipes), `templates/` (the stamped files).
The convention in one line: `<type>(<scope>): Sentence case ending with period.` — subject only, one logical change per commit, gate green before each, commit locally and stop.
