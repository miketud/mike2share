#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------
# 0️⃣  Detect OS and pick a package manager
# -------------------------------------------------
OS=$(uname -s)                                   # from prereq script [1]
case "$OS" in
  Linux*)  PKG=apt   ;;   # extend with dnf/yum/apk if needed
  Darwin*) PKG=brew ;;
  *) echo "Unsupported OS: $OS" && exit 1 ;;
esac
echo "OS=$OS  PKG=$PKG"

# -------------------------------------------------
# 1️⃣  Install any missing generic system tools
# -------------------------------------------------
declare -a MISSING=()
for cmd in git curl wget tar gzip make gcc pkg-config; do
  command -v "$cmd" >/dev/null || MISSING+=("$cmd")
done
if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "Installing missing tools: ${MISSING[*]}"
  case "$PKG" in
    apt)   sudo apt-get update -qq && sudo apt-get install -y "${MISSING[@]}" ;;
    brew)  brew install "${MISSING[@]}" ;;
  esac
fi

# -------------------------------------------------
# 2️⃣  Ensure PostgreSQL client (psql) is present
# -------------------------------------------------
if command -v psql >/dev/null; then
  echo "✅ PostgreSQL client (psql) already installed"
else
  echo "⚠️ PostgreSQL client not found – installing"
  case "$PKG" in
    apt)   sudo apt-get update -qq && sudo apt-get install -y postgresql-client ;;
    brew)  brew install postgresql ;;
    *) echo "Unsupported package manager for PostgreSQL client" && exit 1 ;;
  esac
  echo "✅ PostgreSQL client installed"
fi                                            # from prereq script [1]

# -------------------------------------------------
# 3️⃣  Prompt for project name and create root directory
# -------------------------------------------------
read -rp "Enter project name: " PROJECT_NAME
export PROJECT_NAME
export PROJECT_ROOT="${PWD}/${PROJECT_NAME}"
mkdir -p "$PROJECT_ROOT"
echo "Project root: $PROJECT_ROOT"

# -------------------------------------------------
# 4️⃣  Backend bootstrap
# -------------------------------------------------
#   – ensure env vars are exported (already done above)
if [[ -z "${PROJECT_ROOT:-}" || -z "${PROJECT_NAME:-}" ]]; then
  echo "Error: PROJECT_ROOT and PROJECT_NAME must be exported"
  exit 1
fi

#   Create backend folder
mkdir -p "$PROJECT_ROOT/backend"
cd "$PROJECT_ROOT/backend"

#   Python virtual environment (idempotent)
if [[ ! -d ".venv" ]]; then
  python -m venv .venv
  echo "Virtualenv created at $(pwd)/.venv"
fi
source .venv/bin/activate

#   Install backend dependencies
pip install --upgrade pip
pip install fastapi uvicorn[standard] psycopg2-binary alembic

#   Minimal FastAPI app
mkdir -p app
cat > app/main.py <<'EOF'
from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def root():
    return {"msg": "Hello from FastAPI"}
EOF

#   .env.example for backend
cat > .env.example <<EOF
# PostgreSQL URL – adjust if you use a local instance
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/${PROJECT_NAME}_db
EOF

#   Verbose start script
cat > start.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# Resolve script directory (backend root)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_PATH="${PROJECT_ROOT}/.venv"
source "${VENV_PATH}/bin/activate"

APP_MODULE="app.main:app"
HOST="0.0.0.0"
PORT="8000"

echo "🔹 Starting FastAPI (development mode):"
exec uvicorn ${APP_MODULE} --reload --host ${HOST} --port ${PORT}
EOF
chmod +x start.sh

# -------------------------------------------------
# 5️⃣  Frontend bootstrap
# -------------------------------------------------
cd "$PROJECT_ROOT"
mkdir -p frontend && cd frontend

#   Initialise Next.js (only if not already present)
if [[ ! -f package.json ]]; then
  npx create-next-app@latest . --typescript --eslint --src-dir --app
fi

#   Runtime dependencies
npm install axios react-query zustand classnames dayjs

#   Development‑only tooling
npm install -D eslint prettier \
             @types/node @types/react @types/react-dom \
             jest @testing-library/react @testing-library/jest-dom \
             ts-node typescript

#   Extend .gitignore
cat >> .gitignore <<'EOF'
node_modules/
.next/
.env.local
.env.development
EOF

#   Starter .env.example for the front‑end
cat > .env.example <<EOF
# Base URL of the FastAPI backend
NEXT_PUBLIC_API_URL=http://localhost:8000
EOF

#   Scaffold central Axios client (idempotent)
if [[ ! -f src/api/client.ts ]]; then
  mkdir -p src/api
  cat > src/api/client.ts <<'EOF'
/**
 * Centralised Axios instance.
 * Reads NEXT_PUBLIC_API_URL from the environment (exposed by Next.js).
 */
import axios from 'axios';

if (!process.env.NEXT_PUBLIC_API_URL) {
  throw new Error('NEXT_PUBLIC_API_URL is not defined');
}

const api = axios.create({
  baseURL: process.env.NEXT_PUBLIC_API_URL,
  timeout: 10_000,
  headers: { 'Content-Type': 'application/json' },
});

export default api;
EOF
fi

# -------------------------------------------------
# 6️⃣  Final user hints
# -------------------------------------------------
echo "✅ Backend ready – cd $PROJECT_ROOT/backend && ./start.sh"
echo "✅ Frontend ready – cd $PROJECT_ROOT/frontend && npm run dev"