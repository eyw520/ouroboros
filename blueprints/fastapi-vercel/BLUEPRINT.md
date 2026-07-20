# Blueprint: fastapi-vercel

A full-stack starting point: FastAPI backend, Next.js frontend deployed on Vercel, typed client generated from the backend's OpenAPI spec.
This file is executable documentation: the `/spinup` skill follows it verbatim, and its Decisions and Gotchas seed the new repo's CLAUDE.md — the scaffold and its docs are the same artifact.
Improvements arrive via `/harvest` into this file, never ad-hoc in spawned apps.

## Decisions (each with its why)

- **uv, not poetry** — per DECISIONS.md; the standard's Python preset is the backend's toolchain.
- **Single repo, `backend/` + `frontend/`** — no workspace machinery (pnpm workspaces, turbo) until a second package earns it; premature monorepo plumbing is the most common dead weight in young projects.
- **Frontend by generator, not checked-in skeleton** — `create-next-app` with pinned flags; a checked-in Next skeleton rots with every Next release, while the generator tracks it.
- **Vercel-only deploy to start** — the frontend deploys natively; FastAPI rides Vercel's Python runtime (`backend/api/index.py` exporting the ASGI `app`). One platform, one deploy, zero infra.
  Graduation path (an invariant, not a surprise): the moment you need websockets, background jobs, or long-lived state, move the backend to Fly/Render/AWS unchanged — nothing in the skeleton assumes serverless except `vercel.json`.
- **The typed client is generated, never hand-edited** — per the generated-artifacts pattern: `make api-sync` exports OpenAPI from the running app and regenerates `frontend/lib/api/`; drift is regenerated, not patched.
- **Env contract from birth** — committed `.env.example` documents every variable; real `.env` is gitignored and backstopped by the secret scan.

## Layout

```
backend/
  pyproject.toml        # PEP 621, uv; fastapi + uvicorn; pytest + httpx dev deps
  src/app/main.py       # FastAPI() with /healthz returning {"status": "ok"}
  tests/test_healthz.py # asserts 200 + body via httpx ASGI transport
  api/index.py          # Vercel entry: `from app.main import app`
frontend/               # create-next-app output + lib/api/ (generated client)
Makefile                # verb contract + api-sync, run-backend, run-frontend
vercel.json             # builds: frontend (next) + backend/api (python)
.env.example
```

## Scaffold recipe

1. Backend: write the five files above; `pyproject.toml` pins python via `.python-version` (3.11); `uv sync` creates the venv.
   Makefile verbs map the standard contract: `check` = ruff + ruff format --check + mypy + pytest, `fmt`, `test`, `hooks`, `dev` (hooks + `uv sync` + `pnpm install --dir frontend`).
2. Frontend: `pnpm create next-app@latest frontend --ts --eslint --app --src-dir --no-tailwind --use-pnpm` (adjust flags deliberately, and record why here when you do).
3. `vercel.json`: two builds (`frontend` via `@vercel/next`, `backend/api/index.py` via `@vercel/python`) and a route sending `/api/(.*)` to the backend.
4. `make api-sync`: run the app, `curl /openapi.json` into `frontend/lib/api/openapi.json`, generate the client (`pnpm dlx openapi-typescript`), then format.
5. Governance: `<ouroboros>/init.sh -s "" -l python -c <repo>` — hooks (auto-fix commit-msg, secret-scan, cached pre-commit), `.editorconfig`, AGENTS.md, CI gate.
   The python preset's Makefile DIFFERS from this blueprint's (api-sync verbs) — this blueprint's wins; reconcile by hand.

## Verify (before the first commit — prove it runs, not just that it lints)

1. `cd backend && uv run uvicorn app.main:app --port 8000 &` then `curl -s localhost:8000/healthz` → `{"status":"ok"}`.
2. `make api-sync` → generated client appears and typechecks.
3. `cd frontend && pnpm dev &` → `curl -s localhost:3000` renders; page fetches `/healthz` through the client.
4. Negative probe: `curl -s localhost:8000/nope` → 404 JSON, not a traceback.
5. `make check` green; kill the dev servers; first commit rides the new hooks.

## Gotchas

- Vercel's Python runtime imports `backend/api/index.py` in isolation: keep it a two-line re-export, and keep `src/app` importable via `[tool.uv] package = false` + `pythonpath` in pytest config.
- `pnpm create next-app` refuses a non-empty directory — scaffold frontend before adding overlay files into it.
- The generated client is gitignored? No — commit it (deploys must not depend on a running backend); regeneration keeps it honest.
