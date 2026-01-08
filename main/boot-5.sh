#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------
# UX / logging helpers
# -------------------------------------------------
trap 'echo -e "\n\033[0;31m✖ Failed at line $LINENO\033[0m"; exit 1' ERR

if [[ -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  BLUE='\033[0;34m'
  BOLD='\033[1m'
  DIM='\033[2m'
  NC='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' BOLD='' DIM='' NC=''
fi

section() { echo; echo -e "${BOLD}${BLUE}════════ $1 ════════${NC}"; }
step()    { echo -e "${BLUE}▶${NC} $1"; }
ok()      { echo -e "${GREEN}✔${NC} $1"; }
warn()    { echo -e "${YELLOW}⚠${NC} $1"; }

spinner() {
  local pid=$1
  local spin='|/-\'
  while kill -0 "$pid" 2>/dev/null; do
    for i in {0..3}; do
      printf "\r${DIM}%c${NC}" "${spin:$i:1}"
      sleep 0.1
    done
  done
  printf "\r"
}

run_with_spinner() {
  local label="$1"
  shift

  step "$label"

  "$@" &
  local pid=$!
  spinner $pid
  wait $pid
  local status=$?

  if (( status != 0 )); then
    echo -e "\n${RED}✖ $label failed (exit code $status)${NC}"
    exit 1
  fi
}

START_TIME=$(date +%s)

# -------------------------------------------------
# 0️⃣  Prerequisites – OS detection & package manager
# -------------------------------------------------
section "PREREQUISITES"

OS=$(uname -s)
case "$OS" in
  Linux*)  PKG=apt   ;;
  Darwin*) PKG=brew ;;
  *) echo "Unsupported OS: $OS" && exit 1 ;;
esac
ok "OS=$OS  PKG=$PKG"

# -------------------------------------------------
# 1️⃣  Install generic system tools
# -------------------------------------------------
section "SYSTEM TOOLS"

MISSING=()
for cmd in git curl wget tar gzip make gcc pkg-config; do
  command -v "$cmd" >/dev/null || MISSING+=("$cmd")
done

if (( ${#MISSING[@]} )); then
  step "Installing missing tools: ${MISSING[*]}"
  case "$PKG" in
    apt)   sudo apt-get update -qq && sudo apt-get install -y "${MISSING[@]}" ;;
    brew)  brew install "${MISSING[@]}" ;;
  esac
  ok "System tools installed"
else
  ok "All system tools already present"
fi

# -------------------------------------------------
# 2️⃣  Ensure Node (via NVM) – version 22.21.1
# -------------------------------------------------
section "NODE SETUP"

if ! command -v nvm >/dev/null; then
  step "Installing NVM"
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
  export NVM_DIR="${HOME}/.nvm"
  [ -s "${NVM_DIR}/nvm.sh" ] && . "${NVM_DIR}/nvm.sh"
fi

NODE_VER="22.21.1"
if ! command -v node >/dev/null || [[ "$(node -v)" != "v$NODE_VER" ]]; then
  step "Installing Node $NODE_VER"
  nvm install "$NODE_VER"
  nvm alias default "$NODE_VER"
fi
ok "Node $(node -v) ready"

# -------------------------------------------------
# 3️⃣  Ensure Python ≥3.12 via pyenv
# -------------------------------------------------
section "PYTHON SETUP"

MIN_PY="3.12"

PYVER=$(python3 - <<'EOF' 2>/dev/null || echo "0.0"
import sys
print(f"{sys.version_info.major}.{sys.version_info.minor}")
EOF
)

if [[ "$(printf '%s\n' "$MIN_PY" "$PYVER" | sort -V | head -n1)" != "$MIN_PY" ]]; then
  if ! command -v pyenv >/dev/null; then
    step "Installing pyenv"
    curl -fsSL https://pyenv.run | bash
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"
  fi

  step "Installing Python $MIN_PY"
  pyenv install -s "$MIN_PY"
  pyenv global "$MIN_PY"
fi
ok "Python $(python3 --version) ready"

# -------------------------------------------------
# 4️⃣  Project name / root
# -------------------------------------------------
section "PROJECT SETUP"

if [[ -z "${PROJECT_NAME:-}" ]]; then
  read -rp "Enter project name: " PROJECT_NAME
fi
PROJECT_ROOT="${PWD}/${PROJECT_NAME}"
export PROJECT_ROOT PROJECT_NAME
mkdir -p "$PROJECT_ROOT"
cd "$PROJECT_ROOT"
ok "Project root: $PROJECT_ROOT"

# -------------------------------------------------
# 5️⃣  Root .gitignore
# -------------------------------------------------
step "Writing root .gitignore"
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
ok ".gitignore written"

# -------------------------------------------------
# 6️⃣  BACKEND
# -------------------------------------------------
section "BACKEND SETUP"

mkdir -p backend && cd backend

if [[ ! -d ".venv" ]]; then
  step "Creating virtualenv"
  python3 -m venv .venv
fi
source .venv/bin/activate

step "Installing backend Python dependencies"
pip install --upgrade pip
pip install fastapi "uvicorn[standard]" sqlalchemy psycopg2-binary alembic \
  python-dotenv pytest pytest-asyncio httpx ruff mypy pytest-cov &
spinner $!
wait
pip freeze > requirements.txt
ok "Backend dependencies installed"

# ---- Postgres availability check
if [[ -f .env ]]; then
  set -a; source .env; set +a
fi

if [[ -z "${DATABASE_URL:-}" ]]; then
  warn "DATABASE_URL not set. Skipping Postgres check."
else
  if command -v psql >/dev/null 2>&1; then
    step "Checking Postgres connectivity"
    if ! psql -U postgres -c 'SELECT 1' &> /dev/null; then
    echo "PostgreSQL not found or not running. Checking with Python..."
    python3 -c "import psycopg2; psycopg2.connect(dbname='postgres', user='postgres')" &> /dev/null || {
        echo "PostgreSQL is not running or accessible. Please ensure it's installed and running."
        exit 1
    }
    fi
    ok "Postgres connection OK"
  else
    warn "psql not found. Skipping Postgres check."
  fi
fi

# ---- ruff config
cat > ruff.toml <<'EOF'
[lint]
select = ["E", "F", "W", "C90"]
ignore = []
line-length = 88

[format]
quote-style = "single"
EOF

# ---- Prettier (backend)
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

# ---- pytest config
cat > pytest.ini <<'EOF'
[pytest]
asyncio_mode = auto
addopts = --cov=app --cov-report=term-missing
EOF

# ---- Alembic
if [[ ! -d "alembic" ]]; then
  alembic init alembic
  sed -i.bak 's|sqlalchemy.url = .*|sqlalchemy.url = env:DATABASE_URL|' alembic.ini || true
fi

# ---- FastAPI app
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

# ---- backend .env.example
cat > .env.example <<'EOF'
DATABASE_URL=postgresql://user:password@localhost:5432/dbname
FASTAPI_ENV=development
EOF

# ---- backend .gitignore additions
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

# ---- backend start script
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
ok "Backend ready"

# -------------------------------------------------
# 7️⃣  FRONTEND
# -------------------------------------------------
section "FRONTEND SETUP"
cd "$PROJECT_ROOT"
mkdir -p frontend && cd frontend
if [[ ! -f package.json ]]; then
  step "Creating Next.js app"
  npx create-next-app@latest . --typescript --eslint --src-dir --app
fi
npm pkg set scripts.test="jest"
npm pkg set scripts.format="prettier --write ."
step "Installing frontend dependencies"
npm install axios @tanstack/react-query zustand classnames dayjs &
DEP_PID=$!
spinner $DEP_PID
wait $DEP_PID
DEP_STATUS=$?
if (( DEP_STATUS != 0 )); then
  echo -e "\n${RED}✖ Frontend dependency installation failed (exit code $DEP_STATUS)${NC}"
  exit 1
fi

step "Installing frontend dev tooling"
npm install -D eslint prettier \
  @types/node @types/react @types/react-dom \
  jest @testing-library/react @testing-library/jest-dom \
  ts-node typescript ts-jest @types/jest &
DEV_PID=$!
spinner $DEV_PID
wait $DEV_PID
DEV_STATUS=$?
if (( DEV_STATUS != 0 )); then
  echo -e "\n${RED}✖ Frontend dev‑tooling installation failed (exit code $DEV_STATUS)${NC}"
  exit 1
fi

# ---- jest config
cat > jest.config.ts <<'EOF'
import nextJest from 'next/jest'

const createJestConfig = nextJest({ dir: './' })

const customJestConfig = {
  setupFilesAfterEnv: ['@testing-library/jest-dom'],
  moduleNameMapper: { '^@/(.*)$': '<rootDir>/src/$1' },
}

export default createJestConfig(customJestConfig)
EOF

# ---- example test
mkdir -p src/__tests__
cat > src/__tests__/example.test.ts <<'EOF'
import { render, screen } from '@testing-library/react'
import Home from '@/app/page'

test('renders welcome message', () => {
  render(<Home />)
  expect(screen.getByRole('heading', { name: /welcome/i })).toBeInTheDocument()
})
EOF

# ---- Axios client
mkdir -p src/api
cat > src/api/client.ts <<'EOF'
import axios, { AxiosInstance } from 'axios'

let client: AxiosInstance | null = null

export function getApi(): AxiosInstance {
  if (client) return client
  const baseURL = process.env.NEXT_PUBLIC_API_URL
  if (!baseURL) throw new Error('NEXT_PUBLIC_API_URL not defined')

  client = axios.create({
    baseURL,
    timeout: 10000,
    headers: { 'Content-Type': 'application/json' },
  })

  return client
}
EOF

# ---- stylelint
npm install -D stylelint stylelint-config-standard
cat > .stylelintrc.json <<'EOF'
{ "extends": "stylelint-config-standard", "rules": {} }
EOF

# ---- Prettier (frontend)
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

# ---- frontend .gitignore additions
cat >> .gitignore <<'EOF'
node_modules/
.next/
.env.local
.env.development
EOF

# ---- frontend env example
cat > .env.example <<'EOF'
NEXT_PUBLIC_API_URL=http://localhost:8000
EOF

# ---- next-env.d.ts
if [[ ! -f next-env.d.ts ]]; then
  cat > next-env.d.ts <<'EOF'
/// <reference types="next" />
/// <reference types="next/image-types/global" />
EOF
fi

# -------------------------------------------------
# FINAL
# -------------------------------------------------
END_TIME=$(date +%s)
section "DONE"
ok "Bootstrap completed in $((END_TIME - START_TIME))s"
echo
echo "Backend:  cd $PROJECT_ROOT/backend && ./start.sh"
echo "Frontend: cd $PROJECT_ROOT/frontend && npm run dev"
