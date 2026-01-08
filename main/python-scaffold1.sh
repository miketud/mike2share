#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------
# 0️⃣ Detect OS and select package manager
# -------------------------------------------------
OS=$(uname -s)
case "$OS" in
  Linux*)  PKG=apt   ;;   # extend with dnf/yum/apk if needed
  Darwin*) PKG=brew ;;
  *) echo "Unsupported OS: $OS" && exit 1 ;;
esac
echo "OS=$OS  PKG=$PKG"

# -------------------------------------------------
# 1️⃣ Install missing generic system tools
#    (git, curl, wget, tar, gzip, make, gcc, pkg‑config)
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
# 2️⃣ Ensure PostgreSQL client (psql)
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
fi

# -------------------------------------------------
# 3️⃣ Ensure Python ≥ 3.14 via pyenv
# -------------------------------------------------
MIN_PY=3.14
if command -v python3 >/dev/null; then
  PYVER=$(python3 -c 'import sys;print(f"{sys.version_info.major}.{sys.version_info.minor}")')
  if [[ "$(printf '%s\n' "$MIN_PY" "$PYVER" | sort -V | head -n1)" == "$MIN_PY" ]]; then
    echo "Python $PYVER OK (≥$MIN_PY)"
    HAVE_PYTHON=true
  else
    HAVE_PYTHON=false
  fi
else
  HAVE_PYTHON=false
fi

if [[ ${HAVE_PYTHON:-false} != true ]]; then
  echo "Installing pyenv…"
  curl -fsSL https://pyenv.run | bash
  export PYENV_ROOT="${HOME}/.pyenv"
  export PATH="${PYENV_ROOT}/bin:${PATH}"
  eval "$(pyenv init -)"
fi

# -------------------------------------------------
# 4️⃣ Prompt for project name and create project root
# -------------------------------------------------
read -rp "Enter project name: " PROJECT_NAME
PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}/${PROJECT_NAME}"
mkdir -p "$PROJECT_ROOT"
echo "✅ Project root created at $PROJECT_ROOT"

# -------------------------------------------------
# 5️⃣ Backend scaffold
# -------------------------------------------------
cd "$PROJECT_ROOT"
mkdir -p backend && cd backend

# ----- Python virtual environment -----
if [[ ! -d ".venv" ]]; then
  python -m venv .venv
  echo "Virtualenv created at $(pwd)/.venv"
fi
source .venv/bin/activate

# ----- Install Python dependencies -----
pip install --upgrade pip
pip install fastapi "uvicorn[standard]" sqlalchemy psycopg2-binary alembic \
            python-dotenv pytest pytest-asyncio httpx ruff mypy
pip freeze > requirements.txt

# ----- Alembic init (idempotent) -----
if [[ ! -d "alembic" ]]; then
  alembic init alembic
fi

# ----- Minimal FastAPI app -----
mkdir -p app
cat > app/main.py <<'EOF'
from fastapi import FastAPI
from dotenv import load_dotenv

load_dotenv()
app = FastAPI()

@app.get("/")
def root():
    return {"msg": "Hello from FastAPI"}
EOF

# ----- Backend .env example -----
cat > .env.example <<EOF
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/${PROJECT_NAME}_db
EOF

# ----- Backend start script -----
cat > start.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
VENV_PATH="$(pwd)/.venv"
if [[ ! -d "${VENV_PATH}" ]]; then
  echo "❌ .venv not found at ${VENV_PATH}"
  exit 1
fi
echo "🔹 Activating virtual environment:"
source "${VENV_PATH}/bin/activate"
APP_MODULE="app.main:app"
HOST="0.0.0.0"
PORT="8000"
echo "🔹 Starting FastAPI (development mode):"
exec uvicorn ${APP_MODULE} --reload --host ${HOST} --port ${PORT}
EOF
chmod +x start.sh

# ----- Backend .gitignore -----
cat > .gitignore <<'EOF'
# Byte-compiled / optimized / DLL files
__pycache__/
*.py[cod]
*$py.class

# Python virtual environment
.venv/
env/
venv/
ENV/

# Environment variable files
.env
.env.example

# Log files
*.log

# pytest cache
.pytest_cache/

# IDE / editor artifacts
.idea/
*.swp
EOF

# -------------------------------------------------
# 6️⃣ Frontend scaffold
# -------------------------------------------------
cd "$PROJECT_ROOT"
mkdir -p frontend && cd frontend

# ----- Initialise Next.js app (if not present) -----
if [[ ! -f package.json ]]; then
  npx create-next-app@latest . --typescript --eslint --src-dir --app
fi

# ----- Runtime (production) dependencies -----
npm install axios react-query zustand classnames dayjs

# ----- Development‑only tooling -----
npm install -D eslint prettier \
             @types/node @types/react @types/react-dom \
             jest @testing-library/react @testing-library/jest-dom \
             ts-node typescript

# ----- Extend .gitignore -----
cat >> .gitignore <<'EOF'
node_modules/
.next/
.env.local
.env.development
EOF

# ----- Frontend .env example -----
cat > .env.example <<EOF
# Base URL of the FastAPI backend
NEXT_PUBLIC_API_URL=http://localhost:8000
EOF

# ----- Scaffold central Axios client (idempotent) -----
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
# 7️⃣ Final user hints
# -------------------------------------------------
echo "✅ Backend ready – cd $PROJECT_ROOT/backend && ./start.sh"
echo "✅ Frontend ready – cd $PROJECT_ROOT/frontend && npm run dev"