#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────
# 0️⃣  OS & package‑manager detection
# ──────────────────────────────────────────────────────────────────────
detect_os() {
  case "$(uname -s)" in
    Linux*)   OS="Linux"   ;;
    Darwin*)  OS="macOS"   ;;
    *)        OS="Unsupported" ;;
  esac
  [[ "$OS" == "Unsupported" ]] && { echo "❌ Unsupported OS"; exit 1; }
  echo "🔎 OS: $OS"
}
detect_pkg_manager() {
  if command -v apt-get >/dev/null; then echo "apt";   \
  elif command -v dnf >/dev/null;   then echo "dnf";   \
  elif command -v yum >/dev/null;   then echo "yum";   \
  elif command -v apk >/dev/null;   then echo "apk";   \
  elif command -v brew >/dev/null;  then echo "brew";  \
  else echo "none"; fi
}
detect_os
PKG_MANAGER=$(detect_pkg_manager)
echo "📦 Package manager: $PKG_MANAGER"

# ──────────────────────────────────────────────────────────────────────
# 1️⃣  Collect & install missing system prerequisites
# ──────────────────────────────────────────────────────────────────────
declare -A TOOL_CMD=(
  [git]="git" [curl]="curl" [wget]="wget" [tar]="tar" [gzip]="gzip"
  [make]="make" [gcc]="gcc" [pkg-config]="pkg-config"
  [python3]="python3" [node]="node" [npm]="npm" [nvm]="nvm"
  [pyenv]="pyenv" [docker]="docker"
)
declare -a MISSING_APT=() MISSING_BREW=() MISSING_OTHER=()

collect_missing() {
  for t in "${!TOOL_CMD[@]}"; do
    command -v "${TOOL_CMD[$t]}" >/dev/null 2>&1 || MISSING_OTHER+=("$t")
  done

  if [[ "$OS" == "Linux" ]]; then
    for pkg in libssl-dev libbz2-dev libreadline-dev libsqlite3-dev \
               libncurses5-dev libncursesw5-dev xz-utils tk-dev \
               libffi-dev liblzma-dev; do
      dpkg -s "$pkg" >/dev/null 2>&1 || MISSING_APT+=("$pkg")
    done
  elif [[ "$OS" == "macOS" ]]; then
    for pkg in openssl readline sqlite3 xz tcl-tk libffi; do
      brew list "$pkg" >/dev/null 2>&1 || MISSING_BREW+=("$pkg")
    done
  fi
}
install_missing() {
  collect_missing
  if [[ ${#MISSING_APT[@]} -eq 0 && ${#MISSING_BREW[@]} -eq 0 && ${#MISSING_OTHER[@]} -eq 0 ]]; then
    echo "✅ All system prerequisites satisfied."
    return
  fi
  echo "⚠️ Missing:"
  (( ${#MISSING_APT[@]} ))   && echo " • APT:   ${MISSING_APT[*]}"
  (( ${#MISSING_BREW[@]} ))  && echo " • Brew:  ${MISSING_BREW[*]}"
  (( ${#MISSING_OTHER[@]} )) && echo " • Tools: ${MISSING_OTHER[*]}"
  read -rp $'\nInstall APT/Homebrew packages now? [Y/n] ' ans
  ans=${ans:-Y}
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    case "$PKG_MANAGER" in
      apt)  sudo apt-get update -qq && sudo apt-get install -y "${MISSING_APT[@]}" ;;
      dnf|yum) sudo "$PKG_MANAGER" install -y "${MISSING_APT[@]}" ;;
      apk) sudo apk add "${MISSING_APT[@]}" ;;
      brew) brew install "${MISSING_BREW[@]}" ;;
    esac
    (( ${#MISSING_OTHER[@]} )) && echo "⚠️ Install these manually: ${MISSING_OTHER[*]}"
  else
    echo "🚧 Abort."; exit 1
  fi
}
install_missing

# ──────────────────────────────────────────────────────────────────────
# 2️⃣  Ensure Python ≥3.8 via pyenv (fallback if system python too old)
# ──────────────────────────────────────────────────────────────────────
ensure_python() {
  local min="3.8"
  if command -v python3 >/dev/null; then
    local cur=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    if [[ "$(printf '%s\n' "$min" "$cur" | sort -V | head -n1)" != "$min" ]]; then
      echo "⚠️ System python $cur < $min – installing pyenv."
    else
      echo "✅ System python $cur OK."
      return
    fi
  fi
  echo "🔧 Installing pyenv…"
  curl -fsSL https://pyenv.run | bash
  export PYENV_ROOT="${HOME}/.pyenv"
  export PATH="${PYENV_ROOT}/bin:${PATH}"
  eval "$(pyenv init -)"
  eval "$(pyenv virtualenv-init -)"
  local latest=$(pyenv install -l | grep -E '^\s*3\.[0-9]+\.[0-9]+$' | tail -1 | tr -d ' ')
  pyenv install -s "$latest"
  pyenv global "$latest"
  echo "✅ pyenv Python $latest ready."
}
ensure_python

# ──────────────────────────────────────────────────────────────────────
# 3️⃣  Ensure Node 24.12.0 via NVM
# ──────────────────────────────────────────────────────────────────────
ensure_node() {
  local desired="24.12.0"
  if ! command -v nvm >/dev/null; then
    echo "🔧 Installing NVM…"
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
    export NVM_DIR="${HOME}/.nvm"
    [ -s "${NVM_DIR}/nvm.sh" ] && \. "${NVM_DIR}/nvm.sh"
  fi
  if ! command -v node >/dev/null || [[ "$(node -v)" != "v${desired}" ]]; then
    nvm install "$desired"
    nvm alias default "$desired"
  fi
  echo "✅ Node $(node -v) ready."
}
ensure_node

# ──────────────────────────────────────────────────────────────────────
# 3️⃣  Prompt for project name (idempotent)
# ──────────────────────────────────────────────────────────────────────
read -rp "Enter project name: " PROJECT_NAME
[[ -z "$PROJECT_NAME" ]] && { echo "❌ Project name required"; exit 1; }

ROOT_DIR="${PWD}/${PROJECT_NAME}"
mkdir -p "$ROOT_DIR"
cd "$ROOT_DIR"

# ──────────────────────────────────────────────────────────────────────
# 4️⃣  Backend – FastAPI + Alembic
# ──────────────────────────────────────────────────────────────────────
mkdir -p backend && cd backend
VENV_DIR=".venv"
if [[ -d "$VENV_DIR" ]]; then
  echo "⚙️ Re‑using venv"
else
  echo "🔧 Creating venv"
  python -m venv "$VENV_DIR"
fi
source "$VENV_DIR/bin/activate"
pip install --upgrade pip
pip install \
  fastapi "uvicorn[standard]" sqlalchemy psycopg2-binary alembic \
  python-dotenv pytest pytest-asyncio httpx pytest-cov ruff mypy
pip freeze > requirements.txt

# Alembic init (skip if already present)
if [[ ! -d "alembic" ]]; then
  alembic init alembic
fi

# Minimal FastAPI app structure
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

# .env.example for backend
cat > .env.example <<'EOF'
# Example: postgresql://user:password@localhost:5432/dbname
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/${PROJECT_NAME}_db
EOF

# start script (idempotent)
cat > start.sh <<'EOF'
#!/usr/bin/env bash
source .venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8000
EOF
chmod +x start.sh
cd ..

# ──────────────────────────────────────────────────────────────────────
# 5️⃣  Frontend – Next.js (TS) + Tailwind (optional)
# ──────────────────────────────────────────────────────────────────────
mkdir -p frontend && cd frontend
if [[ ! -f package.json ]]; then
  echo "🚀 Creating Next.js app"
  npx create-next-app@latest . --typescript --eslint --src-dir --app
fi

# Runtime deps
npm install axios react-query zustand classnames dayjs

# Dev‑only tooling (skip if already installed)
npm install -D \
  eslint@latest eslint-config-next@latest prettier@latest \
  @types/node@latest @types/react@latest @types/react-dom@latest \
  jest@latest @testing-library/react@latest @testing-library/jest-dom@latest \
  ts-node@latest typescript@latest

# Ensure lock file
if [[ ! -f package-lock.json ]]; then npm i --package-lock-only; fi

# .gitignore additions
cat >> .gitignore <<'EOF'
node_modules/
.next/
.env.local
.env.development
EOF

# .env.example for frontend (proxy to backend)
cat > .env.example <<EOF
NEXT_PUBLIC_API_URL=http://localhost:8000
EOF

cd ..

# ──────────────────────────────────────────────────────────────────────
# 6️⃣  PostgreSQL – Docker fallback
# ──────────────────────────────────────────────────────────────────────
if command -v docker >/dev/null; then
  if ! docker ps -a --format '{{.Names}}' | grep -q "${PROJECT_NAME}_db"; then
    echo "🐳 Starting PostgreSQL container…"
    docker run -d --name "${PROJECT_NAME}_db" \
      -e POSTGRES_PASSWORD=postgres -p 5432:5432 postgres:15
  else
    echo "✅ PostgreSQL container already running."
  fi
else
  echo "⚠️ Docker not found – you must have a local PostgreSQL instance."
fi

# ──────────────────────────────────────────────────────────────────────
# 7️⃣  Port availability checks (optional but helpful)
# ──────────────────────────────────────────────────────────────────────
check_port() {
  local port=$1
  if ss -ltn | awk '{print $4}' | grep -q ":$port\$"; then
    echo "⚠️ Port $port already in use – you may need to free it."
  else
    echo "✅ Port $port free."
  fi
}
check_port 3000   # Next.js
check_port 8000   # FastAPI (default)

# ──────────────────────────────────────────────────────────────────────
# 8️⃣  README skeleton
# ──────────────────────────────────────────────────────────────────────
cat > README.md <<EOF
# $PROJECT_NAME

## Stack
- **Backend** – FastAPI, SQLAlchemy, Alembic, PostgreSQL (Docker fallback)  
- **Frontend** – Next.js (TypeScript), Tailwind, Axios, React‑Query, Zustand  

## Quick start

### Backend
```bash
cd backend
source .venv/bin/activate
# run migrations (first time only)
alembic upgrade head
./start.sh   # or: uvicorn app.main:app --reload