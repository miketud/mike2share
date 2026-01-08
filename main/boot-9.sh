#!/usr/bin/env bash
set -euo pipefail

# =================================================
# UX / logging helpers
# =================================================
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
  spinner "$pid"
  wait "$pid"
  local status=$?

  if (( status != 0 )); then
    echo -e "\n${RED}✖ $label failed (exit code $status)${NC}"
    exit 1
  fi
}

START_TIME=$(date +%s)

# =================================================
# Prerequisites – OS detection & package manager
# =================================================
section "PREREQUISITES"

OS=$(uname -s)
case "$OS" in
  Linux*)  PKG=apt  ;;
  Darwin*) PKG=brew ;;
  *) echo "Unsupported OS: $OS" && exit 1 ;;
esac

ok "OS=$OS  PKG=$PKG"

# =================================================
# Install generic system tools
# =================================================
section "SYSTEM TOOLS"

MISSING=()
for cmd in git curl wget tar gzip make gcc pkg-config; do
  command -v "$cmd" >/dev/null || MISSING+=("$cmd")
done

if (( ${#MISSING[@]} )); then
  case "$PKG" in
    apt)
      run_with_spinner "Updating apt package index" \
        sudo apt-get update -qq

      run_with_spinner "Installing system packages: ${MISSING[*]}" \
        sudo apt-get install -y "${MISSING[@]}"
      ;;
    brew)
      run_with_spinner "Installing system packages: ${MISSING[*]}" \
        brew install "${MISSING[@]}"
      ;;
  esac
  ok "System tools installed"
else
  ok "All system tools already present"
fi

# =================================================
# Ensure Node (via NVM) – version 22.21.1
# =================================================
section "NODE SETUP"

if ! command -v nvm >/dev/null; then
  step "Installing NVM"
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
fi

NODE_VER="22.21.1"
if ! command -v node >/dev/null || [[ "$(node -v)" != "v$NODE_VER" ]]; then
  step "Installing Node $NODE_VER"
  nvm install "$NODE_VER"
  nvm alias default "$NODE_VER"
fi

ok "Node $(node -v) ready"

# =================================================
# PostgreSQL client check
# =================================================
section "POSTGRESQL CLIENT"

if command -v psql >/dev/null 2>&1; then
  ok "PostgreSQL client already installed ($(psql --version))"
else
  case "$PKG" in
    apt)
      run_with_spinner "Installing PostgreSQL client" \
        sudo apt-get install -y postgresql-client
      ;;
    brew)
      run_with_spinner "Installing PostgreSQL client" \
        brew install libpq
      brew link --force libpq >/dev/null 2>&1 || true
      ;;
  esac

  if ! command -v psql >/dev/null 2>&1; then
    echo -e "\n${RED}✖ PostgreSQL client installation failed${NC}"
    exit 1
  fi

  ok "PostgreSQL client installed ($(psql --version))"
fi

# =================================================
# Ensure Python ≥3.12 via pyenv
# =================================================
section "PYTHON SETUP"

MIN_PY="3.12"
PYVER=$(
  python3 - <<'EOF' 2>/dev/null || echo "0.0"
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
    eval "$(pyenv init --path)"
    eval "$(pyenv init -)"
  fi

  step "Installing Python $MIN_PY"
  pyenv install -s "$MIN_PY"
  pyenv global "$MIN_PY"
fi

ok "Python $(python3 --version) ready"

# =================================================
# Project name / root
# =================================================
section "PROJECT SETUP"

if [[ -z "${PROJECT_NAME:-}" ]]; then
  read -rp "Enter project name: " PROJECT_NAME
fi

PROJECT_ROOT="${PWD}/${PROJECT_NAME}"
export PROJECT_ROOT PROJECT_NAME

mkdir -p "$PROJECT_ROOT"
cd "$PROJECT_ROOT"

ok "Project root: $PROJECT_ROOT"

# ---- initialize a new Git repository
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  step "Initializing Git repository"
  git init -b main
  ok "Git repo initialized"
fi

# =================================================
# Root .gitignore
# =================================================
step "Writing root .gitignore"

cat > .gitignore <<'EOF'
# OS / editor artefacts
.DS_Store
Thumbs.db
.idea/
.vscode/

# Environment files
.env
.env.*

# Backend‑specific Python virtual‑env
.venv/

# Log files
*.log

# Python artefacts
__pycache__/
*.pyc
*.pyo
*.egg-info/
.ruff_cache/
.mypy_cache/

# Node / Next.js artefacts
node_modules/
.next/
dist/
coverage/
build/

# Misc / coverage
coverage/
EOF

# =================================================
# BACKEND
# =================================================
section "BACKEND SETUP"

mkdir -p backend
cd backend

if [[ ! -d ".venv" ]]; then
  step "Creating virtualenv"
  python3 -m venv .venv
fi

source .venv/bin/activate

step "Upgrading pip"
pip install --upgrade pip

run_with_spinner "Installing backend Python packages" \
  pip install fastapi "uvicorn[standard]" sqlalchemy psycopg2-binary alembic \
    python-dotenv pytest pytest-asyncio httpx ruff mypy pytest-cov

pip freeze > requirements.txt
ok "Backend dependencies installed"

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
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv

load_dotenv()

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health")
def health():
    return {"status": "ok"}
EOF

# ---- backend .env.example
cat > .env.example <<'EOF'
DATABASE_URL=postgresql://user:password@localhost:5432/dbname
FASTAPI_ENV=development
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

chmod 750 start.sh
ok "Backend ready"

# =================================================
# FRONTEND
# =================================================
section "FRONTEND SETUP"

mkdir -p frontend
cd frontend

if [[ ! -f package.json ]]; then
  step "Creating Next.js app"
  npx create-next-app@latest . --typescript --eslint --src-dir --app --no-tailwind
fi

# ---- custom landing page (overwrite the default page.tsx)
cat > src/app/page.tsx <<'EOF'
import React from 'react';

export default function Home() {
  return (
    <main className="container mx-auto p-8">
      <h1 className="text-3xl font-bold mb-4">
        Welcome to the Project Starter Kit!
      </h1>

      <section className="mb-6">
        <h2 className="text-2xl font-semibold mb-2">Stack Overview</h2>
        <ul className="list-disc list-inside">
          <li>Backend: Python 3.12 + Ruff linting, FastAPI</li>
          <li>Frontend: Next.js (App Router) + TypeScript</li>
          <li>State: React‑Query, Zustand</li>
          <li>Data fetching: Axios (see src/api/client.ts)</li>
          <li>Styling: vanilla‑extract / CSS classes, Prettier</li>
          <li>Testing: Jest & React Testing Library</li>
        </ul>
      </section>

      <section className="mb-6">
        <h2 className="text-2xl font-semibold mb-2">Next Steps</h2>
        <ol className="list-decimal list-inside">
          <li>Set env vars (e.g., NEXT_PUBLIC_API_URL).</li>
          <li>Run <code>npm test</code> to see the example test pass.</li>
          <li>Start dev server: <code>npm run dev</code>.</li>
          <li>Add pages under <code>src/app/</code> and UI components under <code>src/components/</code>.</li>
        </ol>
      </section>
    </main>
  );
}
EOF

# ---- create an empty folder for shared UI components
mkdir -p src/components   # <-- creates frontend/src/components (empty)

# -------------------------------------------------------------
# 1️⃣  Define npm scripts (all in a single command for clarity)
# -------------------------------------------------------------
npm pkg set \
  scripts.test="jest" \
  scripts.format="prettier --write ." \
  scripts.build="next build" \
  scripts.typecheck="tsc --noEmit"

# -------------------------------------------------------------
# 2️⃣  Add runtime dependencies to package.json (latest versions)
# -------------------------------------------------------------
npm pkg set \
  dependencies."axios"="*" \
  dependencies."@tanstack/react-query"="*" \
  dependencies."zustand"="*" \
  dependencies."classnames"="*" \
  dependencies."dayjs"="*" \
  dependencies."framer-motion"="*" \
  dependencies."@vanilla-extract/css"="*" \
  dependencies."@vanilla-extract/recipes"="*" \
  dependencies."@vanilla-extract/sprinkles"="*" \
  dependencies."gsap"="*" \
  dependencies."react-intersection-observer"="*" \
  dependencies."@use-gesture/react"="*" \
  dependencies."react-use"="*" \
  dependencies."lottie-react"="*" \
  dependencies."react-icons"="*" \
  dependencies."lenis"="*" \
  dependencies."scroll-snap"="*" \
  dependencies."split-type"="*" \
  dependencies."howler"="*"

# -------------------------------------------------------------
# 3️⃣  Install everything deterministically using the lockfile
# -------------------------------------------------------------
run_with_spinner "Installing frontend dependencies" \
  npm ci

# -------------------------------------------------------------
# 4️⃣  Install development‑tooling packages (dev‑dependencies)
# -------------------------------------------------------------
run_with_spinner "Installing frontend dev tooling" \
  npm install -D \
    jest jest-environment-jsdom jest-axe \
    @testing-library/react \
    @testing-library/jest-dom \
    @types/jest @types/jest-axe \
    prettier \
    @vanilla-extract/next-plugin \
    postcss-svgo \
    stylelint stylelint-config-standard

npm pkg set scripts.lint="stylelint '**/*.{css,scss,tsx}' --fix"

# ---- jest config
cat > jest.config.ts <<'EOF'
import nextJest from 'next/jest'

const createJestConfig = nextJest({
  dir: './',
})

const customJestConfig = {
  setupFilesAfterEnv: ['@testing-library/jest-dom'],
  testEnvironment: 'jsdom',
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/src/$1',
  },
}

export default createJestConfig(customJestConfig)
EOF

# ---- example test
mkdir -p src/__tests__
cat > src/__tests__/example.test.tsx <<'EOF'
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import Home from '@/app/page';

test('renders main heading', () => {
  render(<Home />);
  expect(
    screen.getByRole('heading', {
      name: /welcome to the project starter kit!/i,
    }),
  ).toBeInTheDocument();
});
EOF

# ---- accessibility test
cat > src/__tests__/accessibility.test.tsx <<'EOF'
import { render } from '@testing-library/react';
import { axe, toHaveNoViolations } from 'jest-axe';
import Home from '@/app/page';

expect.extend(toHaveNoViolations);

test('Home page has no accessibility violations', async () => {
  const { container } = render(<Home />);
  const results = await axe(container);
  expect(results).toHaveNoViolations();
});
EOF

# ---- Axios client
mkdir -p src/api
cat > src/api/client.ts <<'EOF'
import axios, { AxiosInstance } from 'axios'

let client: AxiosInstance | null = null

export function getApi(): AxiosInstance {
  if (client) return client

  const baseURL = process.env.NEXT_PUBLIC_API_URL
  if (!baseURL) {
    throw new Error('NEXT_PUBLIC_API_URL not defined')
  }

  client = axios.create({
    baseURL,
    timeout: 10000,
    headers: {
      'Content-Type': 'application/json',
    },
  })

  client.interceptors.response.use(
    (response) => response,
    (error) => {
      if (error.response) {
        return Promise.reject({
          status: error.response.status,
          data: error.response.data,
        })
      }
      return Promise.reject({
        message: error.message,
      })
    }
  )

  return client
}
EOF

# ---- stylelint config
cat > .stylelintrc.json <<'EOF'
{
  "extends": "stylelint-config-standard",
  "rules": {}
}
EOF

# ---- PostCSS config
cat > postcss.config.js <<'EOF'
module.exports = {
  plugins: {
    'postcss-svgo': {},
  },
}
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

# =================================================
# FINAL
# =================================================
END_TIME=$(date +%s)

section "DONE"
ok "Bootstrap completed in $((END_TIME - START_TIME))s"

echo
echo "Backend:  cd $PROJECT_ROOT/backend && ./start.sh"
echo "Frontend: cd $PROJECT_ROOT/frontend && npm run dev"
