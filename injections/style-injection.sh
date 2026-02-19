#!/usr/bin/env bash
# --------------------------------------------------------
# style-injection.sh
#   Runs after the full‑stack bootstrap (boot-10.sh)
#   • Updates globals.css with light/dark CSS variables
#   • Rewrites layout.tsx to wrap the app in ThemeProvider
#   • Adds ThemeProvider.tsx and ThemeToggleButton.tsx
# --------------------------------------------------------
set -eu

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

START_TIME=$(date +%s)

# =================================================
# PROJECT SETUP
# =================================================
section "PROJECT SETUP"

# --------------------------------------------------------
# 1️⃣  Get project path from user
# --------------------------------------------------------
echo "Please enter the path to your Next.js project:"
read -r PROJECT_PATH

# Validate project path
if [[ ! -d "$PROJECT_PATH" ]]; then
  printf "${RED}✖ Project path does not exist: %s${NC}\n" "$PROJECT_PATH"
  exit 1
fi
if [[ ! -d "$PROJECT_PATH/frontend" ]]; then
  printf "${RED}✖ Project path does not contain a frontend/ directory: %s${NC}\n" "$PROJECT_PATH"
  exit 1
fi

# --------------------------------------------------------
# 2️⃣  Set project variables
# --------------------------------------------------------
PROJECT_NAME="$(basename "$PROJECT_PATH")"
PROJECT_ROOT="$PROJECT_PATH"
export PROJECT_ROOT PROJECT_NAME

ok "Project root: $PROJECT_ROOT"

# --------------------------------------------------------
# 3️⃣  Move into the project's frontend folder
# --------------------------------------------------------
cd "$PROJECT_ROOT/frontend"

# =================================================
# THEME INJECTION
# =================================================
section "THEME INJECTION"

# --------------------------------------------------------
# 2️⃣  Overwrite globals.css (creates .bak first)
# --------------------------------------------------------
step "Injecting theme CSS into src/app/globals.css"
GLOBAL_CSS_PATH="src/app/globals.css"
if [[ -f "$GLOBAL_CSS_PATH" ]]; then
  cp "$GLOBAL_CSS_PATH" "${GLOBAL_CSS_PATH}.bak"
fi

cat > "$GLOBAL_CSS_PATH" <<'EOF'
/* ---------------------------------------------------------------
   🌐  GLOBAL STYLES – desktop‑first, universal
   --------------------------------------------------------------- */

/* 1️⃣  Box‑sizing & reset */
*, *::before, *::after {
  box-sizing: border-box;
}

html, body, #__next {
  margin: 0;
  padding: 0;
  height: 100%;
  scroll-behavior: smooth;
}

/* 2️⃣  Fluid root font‑size for readable typography */
html {
  font-size: clamp(0.875rem, 0.5vw + 0.5rem, 1rem);
}

/* 3️⃣  CSS‑variables – light (default) */
:root {
  --color-bg: #fafafa;
  --color-text: #111;
  --color-primary: #2563eb;
  --color-primary-hover: #1d4ed8;
  --color-secondary: #64748b;
}

/* 4️⃣  Dark‑mode overrides (data‑theme attribute) */
:root[data-theme="dark"] {
  --color-bg: #111;
  --color-text: #fafafa;
  --color-primary: #60a5fa;
  --color-primary-hover: #3b82f6;
  --color-secondary: #94a3b8;
}

/* 5️⃣  Global element styling */
body {
  background: var(--color-bg);
  color: var(--color-text);
  font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI",
    Roboto, "Helvetica Neue", Arial, "Noto Sans", sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

/* 6️⃣  Utility – universal container */
.container {
  width: 100%;
  max-width: clamp(48rem, 90vw, 120rem); /* 768 px → 1920 px */
  margin-inline: auto;
  padding-inline: 1rem;
}

/* 7️⃣  Accessibility – visible focus ring */
*:focus-visible {
  outline: 2px solid var(--color-primary);
  outline-offset: 2px;
}

/* 8️⃣  Helper class used by the theme toggle button */
.secondary {
  color: var(--color-secondary);
  text-decoration: underline;
}
EOF
ok "globals.css updated (backup at ${GLOBAL_CSS_PATH}.bak)"

# --------------------------------------------------------
# 3️⃣  Overwrite layout.tsx (creates .bak first)
# --------------------------------------------------------
step "Injecting ThemeProvider into src/app/layout.tsx"
LAYOUT_PATH="src/app/layout.tsx"
if [[ -f "$LAYOUT_PATH" ]]; then
  cp "$LAYOUT_PATH" "${LAYOUT_PATH}.bak"
fi

cat > "$LAYOUT_PATH" <<'EOF'
import '@/app/globals.css'
import { ThemeProvider } from '@/app/ThemeProvider'

export const metadata = {
  title: 'Full‑Stack Starter Kit',
  description: 'Next.js + FastAPI starter',
  icons: {
    icon: '/favicon.ico',
    shortcut: '/favicon-16x16.png',
    apple: '/apple-touch-icon.png',
  },
}

/**
 * Root layout – universal, desktop‑first.
 *
 * • Wraps the whole application in <ThemeProvider>.
 * • Uses a global `.container` utility that enforces a
 *   fluid‑max‑width (`clamp(48rem, 90vw, 120rem)`) – this works
 *   consistently on any monitor size without extra media queries.
 * • All visual properties (background, colour, typography…) are
 *   driven by CSS variables defined in `globals.css`.
 */
export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head />
      <body>
        <ThemeProvider>
          {/* Global container – centred, responsive width */}
          <div className="container">
            {children}
          </div>
        </ThemeProvider>
      </body>
    </html>
  )
}
EOF
ok "layout.tsx updated (backup at ${LAYOUT_PATH}.bak)"

# --------------------------------------------------------
# 4️⃣  Add ThemeProvider.tsx (client‑only provider)
# --------------------------------------------------------
step "Creating ThemeProvider component"
PROVIDER_PATH="src/app/ThemeProvider.tsx"
mkdir -p "$(dirname "$PROVIDER_PATH")"

cat > "$PROVIDER_PATH" <<'EOF'
'use client'

import React, { createContext, useEffect, useState, ReactNode } from 'react'

type Theme = 'light' | 'dark'

interface ThemeContextValue {
  theme: Theme
  toggleTheme: () => void
}

/**
 * Small React context that stores the current colour‑scheme.
 * It persists the choice in localStorage and toggles the
 * `data-theme` attribute on <html>.
 */
export const ThemeContext = createContext<ThemeContextValue>({
  theme: 'light',
  toggleTheme: () => {},
})

export function ThemeProvider({ children }: { children: ReactNode }) {
  const [theme, setTheme] = useState<Theme>('light')

  // Initialise from localStorage or system preference
  useEffect(() => {
    const persisted = localStorage.getItem('theme') as Theme | null
    if (persisted) {
      setTheme(persisted)
      document.documentElement.dataset.theme = persisted
      return
    }

    const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches
    const initial = prefersDark ? 'dark' : 'light'
    setTheme(initial)
    document.documentElement.dataset.theme = initial
  }, [])

  // Keep <html data-theme="…"> in sync & persist changes
  const toggleTheme = () => {
    setTheme((prev) => {
      const next = prev === 'light' ? 'dark' : 'light'
      document.documentElement.dataset.theme = next
      localStorage.setItem('theme', next)
      return next
    })
  }

  return (
    <ThemeContext.Provider value={{ theme, toggleTheme }}>
      {children}
    </ThemeContext.Provider>
  )
}
EOF
ok "ThemeProvider.tsx created"

# --------------------------------------------------------
# 5️⃣  Add a tiny toggle button component
# --------------------------------------------------------
step "Creating ThemeToggleButton component"
TOGGLE_PATH="src/components/ThemeToggleButton.tsx"
mkdir -p "$(dirname "$TOGGLE_PATH")"

cat > "$TOGGLE_PATH" <<'EOF'
'use client'

import { useContext } from 'react'
import { ThemeContext } from '@/app/ThemeProvider'
import clsx from 'classnames'

export function ThemeToggleButton() {
  const { theme, toggleTheme } = useContext(ThemeContext)

  return (
    <button
      onClick={toggleTheme}
      className={clsx(
        'px-4 py-2 rounded-lg font-medium transition-colors duration-200 border',
        theme === 'light' 
          ? 'bg-gradient-to-r from-amber-200 to-orange-200 text-sky-600 border-gray-300' 
          : 'bg-gradient-to-r from-blue-900 to-gray-800 text-gray-300 border-gray-600',
      )}
      aria-label="Toggle colour scheme"
    >
      {theme === 'light' ? 'DARK' : 'LIGHT'}
    </button>
  )
}
EOF
ok "ThemeToggleButton.tsx created"

# --------------------------------------------------------
# 6️⃣  (Optional) – expose the toggle in the landing page for a quick demo
# --------------------------------------------------------
STEP_PAGE="src/app/page.tsx"
if grep -q 'ThemeToggleButton' "$STEP_PAGE"; then
  warn "page.tsx already imports ThemeToggleButton – skipping injection"
else
  step "Injecting ThemeToggleButton into the demo page"
  # Insert the import right after the existing imports
  # Insert after line 2 (after 'use client' and before the first import)
  sed -i.bak "3i import { ThemeToggleButton } from '@/components/ThemeToggleButton';" "$STEP_PAGE"
  # Append the component just before the closing </div> (root element)
  awk '
    /<\/div>/ && !found && /style=/ {
      print "        <ThemeToggleButton />"
      found=1
    }
    { print }
  ' "$STEP_PAGE" > "${STEP_PAGE}.tmp" && mv "${STEP_PAGE}.tmp" "$STEP_PAGE"
  ok "Demo page updated (backup at ${STEP_PAGE}.bak)"
fi

# --------------------------------------------------------
# 7️⃣  Print next steps
# --------------------------------------------------------
echo
echo "✅  Theme injection complete!"
echo "   • globals.css → $GLOBAL_CSS_PATH"
echo "   • layout.tsx   → $LAYOUT_PATH"
echo "   • ThemeProvider.tsx → $PROVIDER_PATH"
echo "   • ThemeToggleButton.tsx → $TOGGLE_PATH"
echo
echo "Run the frontend:"
echo "   cd $PROJECT_ROOT/frontend && npm run dev"
echo
echo "Enjoy the light/dark switch!"