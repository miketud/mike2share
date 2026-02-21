#!/usr/bin/env bash

# Print a blue bordered header matching script style
HEADER="Next.js / Fastify Full-Stack Starter"

# Double-line box border for intro section (no side borders)
INTRO_WIDTH=76
BOX_TOP="$(printf '═%.0s' $(seq 1 $INTRO_WIDTH))"
BOX_BOTTOM="$(printf '═%.0s' $(seq 1 $INTRO_WIDTH))"

# Draw top border
echo -e "\033[0;34m$BOX_TOP\033[0m"

# Draw header line (centered)
header_line="$HEADER ($(basename $0))"
padding_left=$(( (INTRO_WIDTH - ${#header_line}) / 2 ))
padding_right=$(( INTRO_WIDTH - ${#header_line} - padding_left ))
echo -e "\033[1;34m$header_line\033[0m\033[0;34m$(printf ' %.0s' $(seq 1 $padding_right))\033[0m"

# Draw section divider
echo -e "\033[0;34m$(printf '─%.0s' $(seq 1 $INTRO_WIDTH))\033[0m"

# Brief overview of the stack and what this script does
echo -e "\033[0;37m This interactive bootstrap script sets up a full‑stack starter combining:\033[0m"
echo -e "\033[0;37m     • Next.js with TypeScript on the frontend\033[0m"
echo -e "\033[0;37m     • Fastify with Prisma and PostgreSQL on the backend\033[0m"
echo -e "\033[0;37m It will guide you through the following steps:\033[0m"
echo -e "\033[0;37m     1. Detect operating system (Linux/macOS) and select package manager\033[0m"
echo -e "\033[0;37m     2. Verify shell configuration and ensure NVM/PNPM paths are set\033[0m"
echo -e "\033[0;37m     3. Install missing system tools (git, curl, wget, tar, gzip, make, gcc, pkg-config)\033[0m"
echo -e "\033[0;37m     4. Install Node.js via NVM (v22.21.1)\033[0m"
echo -e "\033[0;37m     5. Install pnpm package manager\033[0m"
echo -e "\033[0;37m     6. Install PostgreSQL client\033[0m"
echo -e "\033[0;37m     7. Prompt for project name or PATH and create project directory\033[0m"
echo -e "\033[0;37m     8. Scaffold backend (Fastify, Prisma) and frontend (Next.js) with tooling\033[0m"
echo -e "\033[0;37m     9. Set up Git repository and initial .gitignore\033[0m"

# Draw blank line inside box
echo -e "\033[0;37m$(printf ' %.0s' $(seq 1 $INTRO_WIDTH))\033[0m"

# Draw bottom border with prompt
prompt="Press Enter to begin the interactive setup..."
prompt_padding=$(( INTRO_WIDTH - ${#prompt} ))
echo -e "\033[0;37m $prompt\033[0m\033[0;34m$(printf ' %.0s' $(seq 1 $prompt_padding))\033[0m"
echo -e "\033[0;34m$BOX_BOTTOM\033[0m"
read -r

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
   ! grep -q 'PNPM_HOME' "$SHELL_RC" 2>/dev/null; then
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
  echo -e "${YELLOW}The following system tools will be installed:${NC}"
  printf "  %s\n" "${MISSING[@]}"
  read -rp "Do you want to continue? (y/N): " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo -e "\n${RED}Installation cancelled by user${NC}"
    exit 1
  fi
  
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

# Only source NVM if it's already installed (not on fresh install)
if [[ -f "$HOME/.nvm/nvm.sh" ]]; then
  export NVM_DIR="$HOME/.nvm"
  . "$NVM_DIR/nvm.sh"
fi

if ! command -v nvm &>/dev/null; then
  echo -e "${YELLOW}NVM (Node Version Manager) will be installed.${NC}"
  read -rp "Do you want to continue? (y/N): " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo -e "\n${RED}Installation cancelled by user${NC}"
    exit 1
  fi
  step "Installing NVM"
  export NVM_DIR="$HOME/.nvm"
  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
  # Source the shell config to pick up NVM changes
  source "$SHELL_RC"
  # Re-source NVM explicitly
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  ok "NVM installed"
fi

NODE_VER="22.21.1"
if ! command -v node &>/dev/null || [[ "$(node -v)" != "v$NODE_VER" ]]; then
  echo -e "${YELLOW}Node.js $NODE_VER will be installed.${NC}"
  read -rp "Do you want to continue? (y/N): " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo -e "\n${RED}Installation cancelled by user${NC}"
    exit 1
  fi
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
  echo -e "${YELLOW}pnpm (Node package manager) will be installed.${NC}"
  read -rp "Do you want to continue? (y/N): " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo -e "\n${RED}Installation cancelled by user${NC}"
    exit 1
  fi
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
  echo -e "${YELLOW}PostgreSQL client will be installed.${NC}"
  read -rp "Do you want to continue? (y/N): " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo -e "\n${RED}Installation cancelled by user${NC}"
    exit 1
  fi
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

# Log files
*.log
logs/

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

# ---- Install Fastify backend dependencies
step "Installing Fastify backend dependencies"
pnpm add fastify dotenv @types/node

# ---- Install development dependencies
pnpm add -D typescript @types/jest jest ts-jest @types/node @typescript-eslint/eslint-plugin @typescript-eslint/parser eslint prettier

# ---- Install database dependencies
pnpm add pg @prisma/client
pnpm add -D prisma

# ---- Create basic project structure
mkdir -p src src/routes src/controllers src/models src/middleware src/utils

# ---- Create tsconfig.json
cat > tsconfig.json <<'EOF'
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "lib": ["ES2020"],
    "types": ["node"],
    "skipLibCheck": true,
    "esModuleInterop": true,
    "allowSyntheticDefaultImports": true,
    "strict": true,
    "forceConsistentCasingInFileNames": true,
    "noFallthroughCasesInSwitch": true,
    "moduleResolution": "node",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "removeComments": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
EOF

# ---- Create .eslintrc.js
cat > .eslintrc.js <<'EOF'
module.exports = {
  parser: '@typescript-eslint/parser',
  plugins: ['@typescript-eslint'],
  extends: [
    'eslint:recommended',
    '@typescript-eslint/recommended',
  ],
  rules: {
    '@typescript-eslint/no-explicit-any': 'warn',
    '@typescript-eslint/explicit-function-return-type': 'off',
    '@typescript-eslint/explicit-module-boundary-types': 'off',
  },
  env: {
    node: true,
    jest: true,
  },
};
EOF

# ---- Create .prettierrc
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

# ---- Create .prettierignore
cat > .prettierignore <<'EOF'
node_modules/
dist/
*.d.ts
EOF

# ---- Create jest.config.ts
cat > jest.config.ts <<'EOF'
import type { Config } from 'jest';

const config: Config = {
  testEnvironment: 'node',
  transform: {
    '^.+\\.ts$': 'ts-jest',
  },
  testRegex: '(/__tests__/.*|(\\.|/)(test|spec))\\.ts$',
  moduleFileExtensions: ['ts', 'js', 'json', 'node'],
  collectCoverageFrom: [
    'src/**/*.{js,ts}',
    '!src/**/*.d.ts',
  ],
  coverageDirectory: 'coverage',
};

export default config;
EOF

# ---- Create Prisma directory and schema
mkdir -p prisma
cat > prisma/schema.prisma <<'EOF'
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}
EOF

# ---- Create basic Fastify app
cat > src/app.ts <<'EOF'
import fastify from 'fastify'
import { env } from 'process'

const app = fastify({
  logger: true
})

// Health check endpoint
app.get('/health', async () => {
  return { status: 'ok' }
})

export default app
EOF

# ---- Create main server file
cat > src/server.ts <<'EOF'
import app from './app'

const start = async () => {
  try {
    const port = parseInt(process.env.PORT || '3000', 10)
    await app.listen({ port, host: '0.0.0.0' })
    console.log(`Server listening at http://localhost:${port}`)
  } catch (err) {
    console.error(err)
    process.exit(1)
  }
}

start()
EOF

# ---- Create package.json scripts
pnpm pkg set \
  scripts.dev="ts-node src/server.ts" \
  scripts.build="tsc" \
  scripts.start="node dist/server.js" \
  scripts.test="jest" \
  scripts.lint="eslint src/**/*.ts" \
  scripts.format="prettier --write ."

# ---- backend .env.example
cat > .env.example <<'EOF'
DATABASE_URL=postgresql://user:password@localhost:5432/dbname
PORT=3000
NODE_ENV=development
EOF

ok "Backend ready"

# =================================================
# FRONTEND
# =================================================
section "FRONTEND SETUP"

# Ensure we are back at the project root
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

**Production-ready Next.js + Fastify starter with modern tooling**

---

## ⚡ Backend (Node.js + Fastify 4)

### Core Framework
- **Fastify** – High-performance Node.js web framework with excellent TypeScript support
- **TypeScript** – Type-safe development
- **Prisma** – Modern database toolkit with ORM and migrations
- **Jest** – Testing framework with TypeScript support

### Database & Storage
- **PostgreSQL** – Production-grade relational database
- **Prisma Client** – Type-safe database access

### Development Tools
- **ESLint** – Pluggable JavaScript linter
- **Prettier** – Opinionated code formatter
- **TypeScript** – Static type checking

### Utilities
- **dotenv** – Environment variable management
- **node-fetch** – HTTP client for Node.js

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
- **nvm** – Node.js version management (22.21.1)
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
pnpm dev
# API available at http://localhost:3000
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
pnpm test
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
│   ├── src/
│   │   ├── app.ts            # Fastify application
│   │   ├── server.ts         # Server entry point
│   │   ├── routes/           # API routes
│   │   ├── controllers/      # Route handlers
│   │   ├── models/           # Data models
│   │   ├── middleware/       # Request middleware
│   │   └── utils/            # Utility functions
│   ├── prisma/               # Prisma schema and migrations
│   ├── .env.example          # Environment variables
│   ├── package.json          # Node dependencies
│   ├── tsconfig.json         # TypeScript configuration
│   ├── jest.config.ts        # Test configuration
│   └── .prettierrc           # Code formatting rules
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
- Type validation on API boundaries via TypeScript
- SQL injection protection via Prisma ORM
- Password hashing ready (add `bcrypt` when needed)

---

## 📚 Next Steps

1. **Database Setup**: Configure PostgreSQL and run migrations with `prisma migrate dev`
2. **API Development**: Add routes in `backend/src/routes/` and handlers in `backend/src/controllers/`
3. **Frontend Components**: Build UI in `frontend/src/components/`
4. **Authentication**: Add JWT or session-based auth
5. **Deployment**: Configure for Vercel (frontend) + Railway/Render (backend)

---

## 📦 Package Managers

This project uses modern package managers for speed and efficiency:
- **pnpm** for Node.js (2-3x faster than npm, saves disk space)

---

Built with ❤️ using best practices for modern full-stack development
EOF

ok "public/README.md created"

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
    <div style={{ padding: '20px', fontFamily: 'sans-serif' }}>
      {/* Header */}
      <header
        style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          paddingBottom: '10px',
          borderBottom: '10px solid #546',
        }}
      >
        <h1 style={{ margin: 0, fontSize: '1.5rem' }}>
          Next.js/TypeScript + Fastify Bootstrap
        </h1>
        <div style={{ display: 'flex', gap: '10px', alignItems: 'center' }}>
          <button
            onClick={toggleInfo}
            style={{
              padding: '8px 16px',
              cursor: 'pointer',
              fontSize: '14px',
            }}
          >
            {loading ? 'Loading...' : showInfo ? 'Hide README' : 'README'}
          </button>
        </div>
      </header>

      {/* README Section */}
      {showInfo && (
        <section style={{ marginTop: 0 }}>
          <div
            style={{
              padding: '15px',
              fontFamily: 'monospace',
              whiteSpace: 'pre-wrap',
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

# ---- create a folder for shared styles
mkdir -p src/styles

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
  expect(screen.getByText(/Next.js\/TypeScript \+ Fastify Bootstrap/i)).toBeInTheDocument();
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
NEXT_PUBLIC_API_URL=http://localhost:3000
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
echo -e "  • Time:     ${ELAPSED}s"
echo
echo -e "${BOLD}Next steps:${NC}"
echo -e "  1. Configure your environment:"
echo -e "     ${DIM}cp backend/.env.example backend/.env${NC}"
echo -e "     ${DIM}cp frontend/.env.example frontend/.env.local${NC}"
echo
echo -e "  2. Start development servers:"
echo -e "     ${DIM}cd $PROJECT_ROOT/backend && pnpm dev${NC}"
echo -e "     ${DIM}cd $PROJECT_ROOT/frontend && pnpm dev${NC}"
echo
if [[ "${NEEDS_RELOAD:-false}" == "true" ]]; then
  echo -e "${YELLOW}⚠ Don't forget to reload your shell:${NC}"
  echo -e "     ${DIM}source $SHELL_RC${NC}"
  echo
fi