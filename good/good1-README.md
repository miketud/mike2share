# Project Starter Kit

A single script (`setup/stable/strapped1.sh`) that bootstraps a full‑stack starter project with:

- **Backend**: FastAPI, SQLAlchemy, Alembic, Pytest, Ruff, MyPy, Python ≥ 3.12 (via pyenv)
- **Frontend**: Next.js (App Router) + TypeScript, React‑Query, Zustand, Axios, Jest, Prettier, Stylelint

## What the script does (concise)

1. **Detect OS** – selects `apt` (Linux) or `brew` (macOS) as package manager.
2. **Installs system tools** (`git`, `curl`, `wget`, `make`, `gcc`, …) if missing.
3. **Installs Node** via **nvm** (v22.21.1).
4. **Installs PostgreSQL client** (`psql`).
5. **Installs Python ≥ 3.12** via **pyenv**.
6. **Prompts for project name** and creates the project root.
7. **Initializes Git repo** and writes a root `.gitignore`.

### Backend setup

- Creates `backend/` folder with a Python virtualenv.
- Installs dependencies (`fastapi`, `uvicorn`, `sqlalchemy`, `psycopg2-binary`, `alembic`, etc.).
- Generates `requirements.txt`, `ruff.toml`, Prettier config, pytest config.
- Sets up Alembic migrations (`alembic/`).
- Adds a minimal FastAPI app (`app/main.py`) with CORS and health endpoint.
- Writes example `.env.example` and a `start.sh` script to run `uvicorn`.

### Frontend setup

- Creates `frontend/` folder, runs `npx create-next-app` (TypeScript, ESLint, src-dir, app router).
- Overwrites the default landing page (`src/app/page.tsx`).
- Adds an empty `src/components/` directory for shared UI.
- Installs runtime deps (`axios`, `@tanstack/react-query`, `zustand`, `classnames`, `dayjs`, `framer-motion`).
- Installs dev tooling (`jest`, `@testing-library/*`, `prettier`, `stylelint`).
- Sets up Jest config, example test, Axios client, Prettier & Stylelint configs.
- Updates `.gitignore` and provides a frontend `.env.example`.

## Running the project

```bash
# Backend
cd <project_root>/backend && ./start.sh

# Frontend
cd <project_root>/frontend && npm run dev
```
