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
  printf "\r \r"  # Clear the spinner with space, then return to start
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
# Shell configuration check
# =================================================
section "SHELL CONFIGURATION"

if [[ -f "$HOME/.zshrc" ]]; then
  SHELL_RC="$HOME/.zshrc"
  ok "Using zsh ($SHELL_RC)"
elif [[ -f "$HOME/.bashrc" ]]; then
  SHELL_RC="$HOME/.bashrc"
  ok "Using bash ($SHELL_RC)"
else
  warn "No .bashrc or .zshrc found, will create .bashrc"
  SHELL_RC="$HOME/.bashrc"
fi

export SHELL_RC
export NEEDS_RELOAD=false

# Check if paths are in shell config
if ! grep -q 'NVM_DIR' "$SHELL_RC" 2>/dev/null || \
   ! grep -q 'PNPM_HOME' "$SHELL_RC" 2>/dev/null || \
   ! grep -q 'PYENV_ROOT' "$SHELL_RC" 2>/dev/null; then
  NEEDS_RELOAD=true
fi

if [[ "$NEEDS_RELOAD" == "true" ]]; then
  warn "Some tools will modify your shell config"
  warn "After bootstrap completes, run: source $SHELL_RC"
  echo
fi

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

# Source NVM if it exists (needed for both new installs and existing setups)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

if ! command -v nvm &>/dev/null; then
  step "Installing NVM"
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
  # Re-source after fresh install
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  ok "NVM installed"
fi

NODE_VER="22.21.1"
if ! command -v node &>/dev/null || [[ "$(node -v)" != "v$NODE_VER" ]]; then
  step "Installing Node $NODE_VER"
  nvm install "$NODE_VER"
  nvm alias default "$NODE_VER"
  ok "Node $NODE_VER installed"
fi

ok "Node $(node -v) ready"

# =================================================
# Ensure pnpm is installed globally
# =================================================
section "PNPM SETUP"

# Add pnpm to PATH if it exists (needed for detection)
export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"

if ! command -v pnpm &> /dev/null; then
  step "Installing pnpm (Node package manager)"
  curl -fsSL https://get.pnpm.io/install.sh | sh -
  ok "pnpm installed"
else
  PNPM_VERSION=$(pnpm --version)
  ok "pnpm already installed ($PNPM_VERSION)"
fi

# Ensure pnpm is in shell config (whether newly installed or pre-existing)
if ! grep -q 'PNPM_HOME' "$SHELL_RC" 2>/dev/null; then
  step "Adding pnpm to $SHELL_RC"
  cat >> "$SHELL_RC" <<'PNPM_CONFIG'
# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
PNPM_CONFIG
  ok "pnpm added to shell config"
  NEEDS_RELOAD=true
fi

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

# Source pyenv if it exists
export PYENV_ROOT="$HOME/.pyenv"
if [ -d "$PYENV_ROOT" ]; then
  export PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init --path 2>/dev/null)"
  eval "$(pyenv init - 2>/dev/null)"
fi

MIN_PY="3.12"
PYVER=$(
  python3 - <<'EOF' 2>/dev/null || echo "0.0"
import sys
print(f"{sys.version_info.major}.{sys.version_info.minor}")
EOF
)

if [[ "$(printf '%s\n' "$MIN_PY" "$PYVER" | sort -V | head -n1)" != "$MIN_PY" ]]; then
  if ! command -v pyenv &>/dev/null; then
    step "Installing pyenv"
    
    # Install build dependencies
    case "$PKG" in
      apt)
        run_with_spinner "Installing Python build dependencies" \
          sudo apt-get install -y build-essential libssl-dev zlib1g-dev \
          libbz2-dev libreadline-dev libsqlite3-dev curl \
          libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev
        ;;
      brew)
        run_with_spinner "Installing Python build dependencies" \
          brew install openssl readline sqlite3 xz zlib tcl-tk
        ;;
    esac
    
    curl -fsSL https://pyenv.run | bash
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init --path)"
    eval "$(pyenv init -)"
    ok "pyenv installed"
  fi

  step "Installing Python $MIN_PY"
  pyenv install -s "$MIN_PY"
  pyenv global "$MIN_PY"
  pyenv rehash
  ok "Python $MIN_PY installed"
fi

ok "Python $(python3 --version) ready"

# =================================================
# Ensure uv is installed globally
# =================================================
section "UV SETUP"

# Add ~/.local/bin to PATH for uv detection (persists for this script run)
export PATH="$HOME/.local/bin:$PATH"

if ! command -v uv &> /dev/null; then
  step "Installing uv (Python package installer)"
  curl -LsSf https://astral.sh/uv/install.sh | sh
  # Source the env file to ensure uv is available immediately
  [ -f "$HOME/.local/bin/env" ] && source "$HOME/.local/bin/env"
  ok "uv installed"
else
  UV_VERSION=$(uv --version)
  ok "uv already installed ($UV_VERSION)"
fi

# =================================================
# Project name / root
# =================================================
section "PROJECT SETUP"

if [[ -z "${PROJECT_NAME:-}" ]]; then
  read -rp "Enter project name (can include path): " PROJECT_NAME
fi

# Expand tilde and resolve path
PROJECT_NAME="${PROJECT_NAME/#\~/$HOME}"

# Safety check: prevent accidental root-level creation
if [[ "$PROJECT_NAME" == /* ]] && [[ ! "$PROJECT_NAME" =~ ^/home/ ]] && [[ ! "$PROJECT_NAME" =~ ^/Users/ ]]; then
  echo -e "\n${RED}✖ Creating projects in system directories is not allowed${NC}"
  echo "Use a path like ~/projects/test or ./test instead"
  exit 1
fi

# Handle path in project name - extract directory and basename
if [[ "$PROJECT_NAME" == */* ]]; then
  # Contains a slash - extract path and name
  PROJECT_PATH=$(dirname "$PROJECT_NAME")
  PROJECT_NAME=$(basename "$PROJECT_NAME")
  
  # Create parent directory if it doesn't exist
  mkdir -p "$PROJECT_PATH"
  
  # Convert to absolute path
  PROJECT_PATH=$(cd "$PROJECT_PATH" && pwd)
else
  # No path - use current directory
  PROJECT_PATH=$(pwd)
fi

PROJECT_ROOT="${PROJECT_PATH}/${PROJECT_NAME}"
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
*.swp
*.swo
*~

# Environment files
.env
.env.*
!.env.example

# Backend‑specific Python virtual‑env
.venv/
venv/
env/

# Log files
*.log
logs/

# Python artefacts
__pycache__/
*.pyc
*.pyo
*.pyd
*.egg-info/
.ruff_cache/
.mypy_cache/
.pytest_cache/

# Node / Next.js artefacts
node_modules/
.next/
dist/
coverage/
build/
.turbo/
out/

# pnpm
pnpm-lock.yaml

# Database
*.db
*.sqlite
*.sqlite3
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

pip install fastapi 'uvicorn[standard]' sqlalchemy psycopg2-binary alembic \
    python-dotenv pydantic-settings \
    pytest pytest-asyncio pytest-cov httpx tenacity \
    ruff mypy black pre-commit \
    tiktoken structlog tqdm \
    unstructured python-docx pdfminer.six \
    orjson

pip freeze > requirements.txt
ok "Backend dependencies installed"

# ---- VSCode settings for Python
step "Configuring VSCode Python settings"
mkdir -p .vscode
cat > .vscode/settings.json <<'EOF'
{
  "python.defaultInterpreterPath": "${workspaceFolder}/backend/.venv/bin/python",
  "python.analysis.extraPaths": ["${workspaceFolder}/backend"],
  "python.terminal.activateEnvironment": true
}
EOF
ok "VSCode settings created"

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

# Deactivate Python venv before working with Node
deactivate 2>/dev/null || true

# Ensure we are back at the project root (may still be inside backend)
cd "$PROJECT_ROOT"

mkdir -p frontend
cd frontend

if [[ ! -f package.json ]]; then
  step "Creating Next.js app"
  npx create-next-app@latest . --ts --eslint --src-dir --app --no-tailwind --react-compiler --import-alias "@/*" --use-pnpm
fi

# -------------------------------------------------
# Ensure the public folder exists and create README.md
# -------------------------------------------------
step "Adding public/README.md"
if [[ ! -d public ]]; then
  mkdir -p public
  ok "public folder created"
fi

cat > public/README.md <<'EOF'
# 🚀 Full-Stack Starter Kit

**Production-ready Next.js + FastAPI starter with modern tooling**

---

## 🐍 Backend (Python 3.12)

### Core Framework
- **FastAPI** – High-performance async API with automatic OpenAPI docs
- **Uvicorn** – Lightning-fast ASGI server with hot reload
- **SQLAlchemy** – Powerful ORM with async support
- **Alembic** – Database migrations with version control
- **Pydantic** – Runtime type validation and settings management

### Database & Storage
- **PostgreSQL** – Production-grade relational database
- **psycopg2-binary** – PostgreSQL adapter

### Development Tools
- **pytest** + **pytest-asyncio** – Async test suite with coverage
- **Ruff** – Fast Python linter (replaces Flake8, isort, pyupgrade)
- **Black** – Opinionated code formatter
- **Mypy** – Static type checking
- **pre-commit** – Git hooks for quality checks

### Utilities
- **python-dotenv** – Environment variable management
- **structlog** – Structured logging
- **tenacity** – Retry logic for external services
- **httpx** – Modern HTTP client for testing

---

## ⚛️ Frontend (Next.js 15 + TypeScript)

### Framework & Routing
- **Next.js 15** – React framework with App Router, SSR, and RSC
- **TypeScript** – Type-safe development
- **React 19** – Latest React features

### State & Data Fetching
- **TanStack Query (React Query)** – Declarative data fetching, caching, and synchronization
- **Zustand** – Lightweight state management (3kb)
- **Axios** – HTTP client with interceptors

### Styling & Animation
- **Vanilla Extract** – Type-safe CSS-in-JS with zero runtime
  - Recipes for component variants
  - Sprinkles for atomic CSS utilities
- **Framer Motion** – Production-grade animations
- **GSAP** – Advanced timeline-based animations
- **next-themes** – Light/dark mode with system preference support

### UI Utilities
- **classnames** – Conditional className composition
- **dayjs** – Lightweight date manipulation (2kb vs 66kb for Moment)
- **lottie-react** – High-quality animations
- **react-icons** – Icon library
- **react-markdown** – Markdown rendering
- **react-intersection-observer** – Viewport detection
- **@use-gesture/react** – Touch/mouse gesture recognition
- **react-use** – Essential React hooks collection

### Scroll & Interaction
- **Lenis** – Smooth scroll library
- **scroll-snap** – Scroll snapping utilities
- **split-type** – Text animation utilities
- **howler** – Web audio management

### Testing & Quality
- **Jest** + **React Testing Library** – Component testing
- **jest-axe** – Accessibility testing
- **Prettier** – Code formatting
- **Stylelint** – CSS/SCSS linting
- **TypeScript** – Type checking

---

## 🛠️ Tooling & Package Management

### Version Management
- **pyenv** – Python version management (3.12+)
- **nvm** – Node.js version management (22.21.1)
- **uv** – Fast Python package installer (Rust-based, replaces pip)
- **pnpm** – Fast, disk-efficient Node package manager

### System Requirements
- **build-essential** (Linux) / **Xcode CLI Tools** (macOS) – Compilers for native extensions
- **PostgreSQL client** – Database connection tools
- **Git** – Version control with main branch initialized

---

## 🎨 Design System

### Theme Variables
CSS custom properties for consistent theming:
- `--background` / `--foreground` – Base colors
- Automatic dark mode via `prefers-color-scheme`
- Theme switching with `next-themes`

---

## 🚀 Quick Start

### 1. Configure Environment
```bash
# Backend
cp backend/.env.example backend/.env
# Edit backend/.env with your database credentials

# Frontend
cp frontend/.env.example frontend/.env.local
# Edit frontend/.env.local with your API URL
```

### 2. Start Development Servers

**Backend:**
```bash
cd backend
./start.sh
# API available at http://localhost:8000
# OpenAPI docs at http://localhost:8000/docs
```

**Frontend:**
```bash
cd frontend
pnpm dev
# App available at http://localhost:3000
```

### 3. Run Tests

**Backend:**
```bash
cd backend
source .venv/bin/activate
pytest
```

**Frontend:**
```bash
cd frontend
pnpm test
```

---

## 📁 Project Structure
```
.
├── backend/
│   ├── app/
│   │   └── main.py          # FastAPI application
│   ├── alembic/             # Database migrations
│   ├── .venv/               # Python virtual environment
│   ├── requirements.txt     # Python dependencies
│   ├── pytest.ini           # Test configuration
│   ├── ruff.toml           # Linter configuration
│   └── start.sh            # Development server script
│
├── frontend/
│   ├── src/
│   │   ├── app/            # Next.js App Router
│   │   ├── components/     # Shared React components
│   │   ├── api/            # Axios client configuration
│   │   └── __tests__/      # Test files
│   ├── public/             # Static assets
│   ├── package.json        # Node dependencies
│   ├── tsconfig.json       # TypeScript configuration
│   ├── jest.config.ts      # Test configuration
│   └── .prettierrc         # Code formatting rules
│
└── .gitignore              # Git exclusions
```

---

## 🔒 Security Best Practices

- Environment variables for sensitive data (`.env` files gitignored)
- CORS configured for development (update for production)
- Type validation on API boundaries via Pydantic
- SQL injection protection via SQLAlchemy ORM
- Password hashing ready (add `passlib[bcrypt]` when needed)

---

## 📚 Next Steps

1. **Database Setup**: Configure PostgreSQL and run migrations with `alembic upgrade head`
2. **API Development**: Add routes in `backend/app/` and models in `backend/app/models/`
3. **Frontend Components**: Build UI in `frontend/src/components/`
4. **Authentication**: Add JWT or session-based auth
5. **Deployment**: Configure for Vercel (frontend) + Railway/Render (backend)

---

## 📦 Package Managers

This project uses modern package managers for speed and efficiency:
- **uv** for Python (50-100x faster than pip)
- **pnpm** for Node.js (2-3x faster than npm, saves disk space)

---

Built with ❤️ using best practices for modern full-stack development
EOF

ok "public/README.md created"

# ----------------------------------------------------
# 2️⃣ Write a theme‑aware globals.css (light + dark)
# ----------------------------------------------------
step "Writing theme‑aware globals.css"

cat > src/app/globals.css <<'EOF'
:root {
  --background: #ffffff;
  --foreground: #171717;
}

/* Dark mode overrides – automatically applied when the OS prefers dark */
@media (prefers-color-scheme: dark) {
  :root {
    --background: #0a0a0a;
    --foreground: #ededed;
  }
}

/* Global resets & base styles */
html,
body {
  max-width: 100vw;
  overflow-x: hidden;
  color: var(--foreground);
  background: var(--background);
  font-family: Arial, Helvetica, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

*,
*::before,
*::after {
  box-sizing: inherit;
  margin: 0;
  padding: 0;
}

/* Links inherit color */
a {
  color: inherit;
  text-decoration: none;
}

/* Ensure browsers know we support dark mode (helps UI widgets) */
@media (prefers-color-scheme: dark) {
  html {
    color-scheme: dark;
  }
}
EOF

ok "globals.css with light & dark theme variables written"

# ---- custom landing page (overwrite the default page.tsx)
cat > src/app/page.tsx <<'EOF'
'use client';

import { useState } from 'react';

export default function LandingPage() {
  const [showInfo, setShowInfo] = useState(false);
  const [readmeContent, setReadmeContent] = useState('');
  const [loading, setLoading] = useState(false);

  const toggleInfo = async () => {
    // If we are about to show the info and README hasn't been loaded yet, fetch it
    if (!showInfo && readmeContent === '') {
      setLoading(true);
      try {
        const res = await fetch('/README.md');
        const text = await res.text();
        setReadmeContent(text);
      } catch (err) {
        console.error('Failed to load README.md', err);
        setReadmeContent('Unable to load README from /frontend/public/');
      }
      setLoading(false);
    }
    setShowInfo(!showInfo);
  };

  return (
    <div
      style={{
        minHeight: '100vh',
        background: '#ffffff',
        display: 'flex',
        flexDirection: 'column',
      }}
    >
      {/* Header */}
      <header
        style={{
          width: '100%',
          background: '#def',
          color: '#000000',
          padding: '1rem 2rem',
          borderBottom: '4px solid #000000',
          display: 'flex',
          alignItems: 'center',
          fontSize: '1.5rem',
          fontWeight: 600,
          marginLeft: '1rem',
        }}
      >
        <div>Next.js/TypeScript + Python Bootstrap</div>
        <button
          onClick={toggleInfo}
          style={{
            background: '#ffffff',
            color: '#000000',
            border: '2px solid #000000',
            padding: '0.5rem 1rem',
            borderRadius: '4px',
            fontSize: '1rem',
            cursor: 'pointer',
          }}
        >
          {loading ? 'Loading...' : showInfo ? 'Hide README' : 'README'}
        </button>
      </header>

      {/* README Section */}
      {showInfo && (
        <section
          style={{
            maxWidth: '80%',
            width: '100%',
            padding: '2rem',
            background: '#ffffff',
          }}
        >
          <div
            style={{
              color: '#334155',
              whiteSpace: 'pre-wrap',
              fontFamily: 'monospace',
              lineHeight: '1.6',
            }}
          >
            {readmeContent || 'No content available'}
          </div>
        </section>
      )}
    </div>
  );
}
EOF

# ---- create an empty folder for shared UI components
mkdir -p src/components

# -------------------------------------------------------------
# Define package.json scripts and dependencies
# -------------------------------------------------------------
step "Configuring package.json"

pnpm pkg set \
  scripts.dev="next dev" \
  scripts.build="next build" \
  scripts.start="next start" \
  scripts.test="jest" \
  scripts.lint="stylelint '**/*.{css,scss,tsx}' --fix" \
  scripts.format="prettier --write ." \
  scripts.typecheck="tsc --noEmit"

pnpm pkg set \
  dependencies.axios="*" \
  dependencies."@tanstack/react-query"="*" \
  dependencies.zustand="*" \
  dependencies.classnames="*" \
  dependencies.dayjs="*" \
  dependencies."framer-motion"="*" \
  dependencies."@vanilla-extract/css"="*" \
  dependencies."@vanilla-extract/recipes"="*" \
  dependencies."@vanilla-extract/sprinkles"="*" \
  dependencies.gsap="*" \
  dependencies."react-intersection-observer"="*" \
  dependencies."@use-gesture/react"="*" \
  dependencies."react-use"="*" \
  dependencies."lottie-react"="*" \
  dependencies."react-icons"="*" \
  dependencies."react-markdown"="*" \
  dependencies.lenis="*" \
  dependencies."scroll-snap"="*" \
  dependencies."split-type"="*" \
  dependencies.howler="*"

ok "package.json configured"

# -------------------------------------------------------------
# Install all dependencies in one command
# -------------------------------------------------------------
run_with_spinner "Installing frontend dependencies (this may take a minute)" \
  pnpm install \
    jest \
    jest-environment-jsdom \
    jest-axe \
    @testing-library/react \
    @testing-library/jest-dom \
    @types/jest \
    @types/jest-axe \
    prettier \
    motion \
    next-themes \
    @vanilla-extract/next-plugin \
    postcss-svgo \
    stylelint \
    stylelint-config-standard \
    --save-dev

ok "Frontend dependencies installed"

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

test('renders landing page', () => {
  render(<Home />);
  expect(screen.getByText(/Next.js\/TypeScript \+ Python Bootstrap/i)).toBeInTheDocument();
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
# COMPLETE
# =================================================
section "COMPLETE"

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

echo -e "${GREEN}${BOLD}✨ Bootstrap completed successfully!${NC}"
echo
echo -e "${BOLD}Project Summary:${NC}"
echo -e "  • Name:     ${BOLD}$PROJECT_NAME${NC}"
echo -e "  • Location: ${DIM}$PROJECT_ROOT${NC}"
echo -e "  • Node:     $(node -v)"
echo -e "  • pnpm:     $(pnpm --version)"
echo -e "  • Python:   $(python3 --version | awk '{print $2}')"
echo -e "  • Time:     ${ELAPSED}s"
echo
echo -e "${BOLD}Next steps:${NC}"
echo -e "  1. Configure your environment:"
echo -e "     ${DIM}cp backend/.env.example backend/.env${NC}"
echo -e "     ${DIM}cp frontend/.env.example frontend/.env.local${NC}"
echo
echo -e "  2. Start development servers:"
echo -e "     ${DIM}cd $PROJECT_ROOT/backend && ./start.sh${NC}"
echo -e "     ${DIM}cd $PROJECT_ROOT/frontend && pnpm dev${NC}"
echo
if [[ "${NEEDS_RELOAD:-false}" == "true" ]]; then
  echo -e "${YELLOW}⚠ Don't forget to reload your shell:${NC}"
  echo -e "     ${DIM}source $SHELL_RC${NC}"
  echo
fi