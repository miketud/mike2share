#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------
# 0️⃣  Prerequisites – OS detection & package manager
# -------------------------------------------------
OS=$(uname -s)
case "$OS" in
  Linux*)  PKG=apt   ;;   # add dnf/yum/apk as needed
  Darwin*) PKG=brew ;;
  *) echo "Unsupported OS: $OS" && exit 1 ;;
esac
echo "OS=$OS  PKG=$PKG"

# -------------------------------------------------
# 1️⃣  Install generic system tools (git, curl, …)
# -------------------------------------------------
MISSING=()
for cmd in git curl wget tar gzip make gcc pkg-config; do
  command -v "$cmd" >/dev/null || MISSING+=("$cmd")
done
if (( ${#MISSING[@]} )); then
  echo "Installing missing tools: ${MISSING[*]}"
  case "$PKG" in
    apt)   sudo apt-get update -qq && sudo apt-get install -y "${MISSING[@]}" ;;
    brew)  brew install "${MISSING[@]}" ;;
  esac
fi

# -------------------------------------------------
# 2️⃣  Ensure Node (via NVM) – version 22.21.1
# -------------------------------------------------
if ! command -v nvm >/dev/null; then
  echo "Installing NVM…"
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
  export NVM_DIR="${HOME}/.nvm"
  [ -s "${NVM_DIR}/nvm.sh" ] && . "${NVM_DIR}/nvm.sh"
fi
NODE_VER="22.21.1"
if ! command -v node >/dev/null || [[ "$(node -v)" != "v$NODE_VER" ]]; then
  nvm install "$NODE_VER"
  nvm alias default "$NODE_VER"
fi
echo "Node $(node -v) ready"

# -------------------------------------------------
# 3️⃣  Ensure Python ≥3.12 via pyenv
# -------------------------------------------------
MIN_PY="3.12"

PYVER=$(python3 - <<'EOF' 2>/dev/null || echo "0.0"
import sys
print(f"{sys.version_info.major}.{sys.version_info.minor}")
EOF
)

if [[ "$(printf '%s\n' "$MIN_PY" "$PYVER" | sort -V | head -n1)" != "$MIN_PY" ]]; then
  if ! command -v pyenv >/dev/null; then
    curl -fsSL https://pyenv.run | bash
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"
  fi

  pyenv install -s "$MIN_PY"
  pyenv global "$MIN_PY"
fi

echo "Python $(python3 --version) ready"

# -------------------------------------------------
# 4️⃣  Prompt for project name / root (or export them beforehand)
# -------------------------------------------------
if [[ -z "${PROJECT_NAME:-}" ]]; then
  read -rp "Enter project name: " PROJECT_NAME
fi
PROJECT_ROOT="${PWD}/${PROJECT_NAME}"
export PROJECT_ROOT PROJECT_NAME

# -------------------------------------------------
# 5️⃣  Create project skeleton
# -------------------------------------------------
mkdir -p "$PROJECT_ROOT"

cd "$PROJECT_ROOT"

# ---- root .gitignore ----------------------------------------------
cat > .gitignore <<'EOF'
# OS / editor
.DS_Store
Thumbs.db
.idea/
.vscode/

# Env
.env
.env.*

# Logs
*.log

# Python
__pycache__/
*.pyc
*.pyo
.ruff_cache/
.mypy_cache/

# Node
node_modules/
.next/
dist/
coverage/

# Build artifacts
build/
EOF

# -------------------------------------------------
# 6️⃣  ---------- BACKEND ----------
# -------------------------------------------------
mkdir -p backend && cd backend

# ---- virtual env -------------------------------------------------
if [[ ! -d ".venv" ]]; then
  python3 -m venv .venv
  echo "Virtualenv created at $(pwd)/.venv"
fi
source .venv/bin/activate

# ---- python package manager --------------------------------------
pip install --upgrade pip
pip install fastapi "uvicorn[standard]" sqlalchemy psycopg2-binary alembic \
            python-dotenv pytest pytest-asyncio httpx ruff mypy pytest-cov

pip freeze > requirements.txt

# ---- Postgres availability check ---------------------------------
if [[ -f .env ]]; then
  set -a
  source .env
  set +a
fi

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "⚠️  DATABASE_URL not set. Skipping Postgres check."
else
  if command -v psql >/dev/null 2>&1; then
    echo "Checking Postgres connectivity…"
    if ! psql "$DATABASE_URL" -c '\q' >/dev/null 2>&1; then
      echo "❌ Cannot connect to Postgres using DATABASE_URL"
      echo "   → Check credentials, host, port, and that Postgres is running"
      exit 1
    fi
    echo "✅ Postgres connection OK"
  else
    echo "⚠️  psql not found. Skipping Postgres connectivity check."
  fi
fi

# ---- ruff (Python linter) config ---------------------------------
cat > ruff.toml <<'EOF'
[lint]
select = ["E", "F", "W", "C90"]
ignore = []
line-length = 88

[format]
quote-style = "single"
EOF

# ---- Prettier config for backend ---------------------------------
cat > .prettierrc <<'EOF'
{
  "singleQuote": true,
  "trailingComma": "all",
  "printWidth": 80
}
EOF
cat > .prettierignore <<'EOF'
__pycache__/
*.pyc
*.egg-info/
EOF

# ---- pytest configuration -----------------------------------------
cat > pytest.ini <<'EOF'
[pytest]
asyncio_mode = auto
addopts = --cov=app --cov-report=term-missing
EOF

# ---- Alembic init (idempotent) ------------------------------------
if [[ ! -d "alembic" ]]; then
  alembic init alembic
  # ---- Alembic config: env-based DB URL -----------------------------
  sed -i.bak 's|sqlalchemy.url = .*|sqlalchemy.url = env:DATABASE_URL|' alembic.ini || true
fi

# ---- Minimal FastAPI app -----------------------------------------
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

# ---- central .env.example for backend -----------------------------
cat > .env.example <<'EOF'
DATABASE_URL=postgresql://user:password@localhost:5432/dbname
# FastAPI settings
FASTAPI_ENV=development
EOF

# ---- backend .gitignore (add python‑specific entries) -------------
cat >> .gitignore <<'EOF'
.venv/
__pycache__/
*.pyc
*.pyo
*.pyd
*.egg-info/
dist/
build/
.env
.ruff_cache/
.mypy_cache/
EOF

# ---- Backend start script -----------------------------------------
cat > start.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
source .venv/bin/activate
APP_MODULE="app.main:app"
HOST="0.0.0.0"
PORT="8000"
exec uvicorn $APP_MODULE --reload --host $HOST --port $PORT
EOF
chmod +x start.sh

# -------------------------------------------------
# 7️⃣  ---------- FRONTEND ----------
# -------------------------------------------------
cd "$PROJECT_ROOT"
mkdir -p frontend && cd frontend

# ---- initialise Next.js only once --------------------------------
if [[ ! -f package.json ]]; then
  npx create-next-app@latest . --typescript --eslint --src-dir --app
fi

# ---- ensure npm scripts (append-safe) ----------------------------
npm pkg set scripts.test="jest"
npm pkg set scripts.format="prettier --write ."

# ---- production dependencies ---------------------------------------
npm install axios @tanstack/react-query zustand classnames dayjs

# ---- development‑only tooling (add ts‑jest) -----------------------
npm install -D eslint prettier \
             @types/node @types/react @types/react-dom \
             jest @testing-library/react @testing-library/jest-dom \
             ts-node typescript \
             ts-jest @types/jest

# ---- add ts‑jest transformer to jest config -----------------------
cat > jest.config.ts <<'EOF'
import nextJest from 'next/jest'

const createJestConfig = nextJest({
  dir: './',               // root of the project
})

const customJestConfig = {
  // any custom settings you need
  setupFilesAfterEnv: ['@testing-library/jest-dom'],
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/src/$1',
  },
}

export default createJestConfig(customJestConfig)
EOF

# ---- basic test file (so jest runs immediately) -----------------
mkdir -p src/__tests__
cat > src/__tests__/example.test.ts <<'EOF'
import { render, screen } from '@testing-library/react';
import Home from '@/app/page';

test('renders welcome message', () => {
  render(<Home />);
  const heading = screen.getByRole('heading', { name: /welcome/i });
  expect(heading).toBeInTheDocument();
});
EOF

# ---- central Axios client (idempotent) ---------------------------
if [[ ! -f src/api/client.ts ]]; then
  mkdir -p src/api
  cat > src/api/client.ts <<'EOF'
import axios, { AxiosInstance } from 'axios';

let client: AxiosInstance | null = null;

export function getApi(): AxiosInstance {
  if (client) return client;

  const baseURL = process.env.NEXT_PUBLIC_API_URL;
  if (!baseURL) {
    throw new Error('NEXT_PUBLIC_API_URL is not defined');
  }

  client = axios.create({
    baseURL,
    timeout: 10000,
    headers: { 'Content-Type': 'application/json' },
  });

  return client;
}
EOF
fi

# ---- stylelint (optional) -----------------------------------------
npm install -D stylelint stylelint-config-standard
cat > .stylelintrc.json <<'EOF'
{
  "extends": "stylelint-config-standard",
  "rules": {}
}
EOF

# ---- Prettier config for frontend ---------------------------------
cat > .prettierrc <<'EOF'
{
  "semi": true,
  "singleQuote": true,
  "trailingComma": "all",
  "printWidth": 80,
  "tabWidth": 2,
  "arrowParens": "always"
}
EOF

cat > .prettierignore <<'EOF'
node_modules/
.next/
dist/
coverage/
EOF

# ---- extend .gitignore --------------------------------------------
cat >> .gitignore <<'EOF'
node_modules/
.next/
.env.local
.env.development
EOF

# ---- .env.example for frontend ------------------------------------
cat > .env.example <<'EOF'
NEXT_PUBLIC_API_URL=http://localhost:8000
EOF

# ---- ensure next‑env.d.ts exists (create if missing) ---------------
if [[ ! -f next-env.d.ts ]]; then
  cat > next-env.d.ts <<'EOF'
/// <reference types="next" />
/// <reference types="next/image-types/global" />
EOF
fi

# -------------------------------------------------
# 7️⃣ Final user hints
# -------------------------------------------------
echo "✅ Backend ready – cd $PROJECT_ROOT/backend && ./start.sh"
echo "✅ Frontend ready – cd $PROJECT_ROOT/frontend && npm run dev"