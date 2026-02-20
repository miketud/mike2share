#!/usr/bin/env bash
# --------------------------------------------------------
# theme-injection.sh
#   Corrected version that properly injects ThemeToggleButton
#   into the landing page header
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
*,
*::before,
*::after {
    box-sizing: border-box;
}

html,
body,
#__next {
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
    --color-border: #000000;
}

/* 4️⃣  Dark‑mode overrides (data‑theme attribute) */
:root[data-theme="dark"] {
    --color-bg: #111;
    --color-text: #fafafa;
    --color-primary: #60a5fa;
    --color-primary-hover: #3b82f6;
    --color-secondary: #94a3b8;
    --color-border: #575757;
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
    max-width: clamp(48rem, 90vw, 120rem);
    /* 768 px → 1920 px */
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

/* 9️⃣  Transition effects for smooth theme switching */
* {
    transition: background-color 0.3s ease, color 0.3s ease, border-color 0.3s ease;
}

/* 🔧  Additional semantic color variables */
:root {
    --color-link: var(--color-primary);
    --color-link-hover: var(--color-primary-hover);
    --color-button-bg: var(--color-bg);
    --color-button-text: var(--color-text);
    --color-button-border: var(--color-border);
    --color-card-bg: var(--color-bg);
    --color-shadow: rgba(0, 0, 0, 0.1);
}

:root[data-theme="dark"] {
    --color-link: var(--color-primary);
    --color-link-hover: var(--color-primary-hover);
    --color-button-bg: var(--color-bg);
    --color-button-text: var(--color-text);
    --color-button-border: var(--color-border);
    --color-card-bg: var(--color-bg);
    --color-shadow: rgba(255, 255, 255, 0.1);
}

/* 🎨  Utility classes for common theme-aware elements */
.card {
    background: var(--color-card-bg);
    border: 1px solid var(--color-button-border);
    border-radius: 8px;
    box-shadow: 0 2px 4px var(--color-shadow);
    padding: 1rem;
}

.link {
    color: var(--color-link);
    text-decoration: none;
    transition: color 0.2s ease;
}

.link:hover {
    color: var(--color-link-hover);
    text-decoration: underline;
}

/* 9️⃣  Page container and layout classes */
.main-container {
    min-height: 100vh;
    background: var(--color-bg);
    display: flex;
    flex-direction: column;
}

.header {
    width: 100%;
    background: var(--color-bg);
    color: var(--color-text);
    padding: 1rem 2rem;
    border-bottom: 4px solid var(--color-text);
    display: flex;
    align-items: center;
    justify-content: space-between;
    font-size: 1.5rem;
    font-weight: 600;
}

.header-title {
    color: var(--color-text);
}

.header-controls {
    display: flex;
    gap: 0.5rem;
}

.readme-button {
    background: var(--color-bg);
    color: var(--color-text);
    border: 2px solid var(--color-text);
    padding: 0.5rem 1rem;
    border-radius: 4px;
    font-size: 1rem;
    cursor: pointer;
}

/* Shared button styles for consistent sizing */
.button {
    padding: 8px 16px;
    cursor: pointer;
    font-size: 14px;
    border-radius: 0.375rem;
    font-weight: 500;
    border: 1px solid var(--color-border);
    transition: color 0.2s ease, background-color 0.2s ease;
    display: inline-block;
    line-height: 1.4;
    background-color: var(--color-button-bg);
    color: var(--color-button-text);
    min-height: 32px;
    height: fit-content;
}

/* Theme-specific button styles */
.button.light-theme {
    background: linear-gradient(to right, #fdecbf, #ffc766);
    /* from-amber-200 to-orange-200 */
    color: #000000;
    /* text-sky-600 */
    border-color: #d1d5db;
    /* border-gray-300 */
}

.button.dark-theme {
    background: linear-gradient(to right, #495578, #1f2937);
    /* from-blue-900 to-gray-800 */
    color: #d1d5db;
    /* text-gray-300 */
    border-color: #4b5563;
    /* border-gray-600 */
}

.readme-section {
    max-width: 80%;
    width: 100%;
    padding: 2rem;
    background: var(--color-bg);
}

.readme-content {
    color: var(--color-text);
    white-space: pre-wrap;
    font-family: monospace;
    line-height: 1.6;
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
import { ThemeProvider } from '@/components/ThemeProvider'

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
PROVIDER_PATH="src/components/ThemeProvider.tsx"
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
# 5️⃣  Add Theme Toggle Button
# --------------------------------------------------------
step "Creating ThemeToggleButton component"
TOGGLE_PATH="src/components/ThemeToggleButton.tsx"
mkdir -p "$(dirname "$TOGGLE_PATH")"

cat > "$TOGGLE_PATH" <<'EOF'
'use client';

import { useContext } from 'react';
import { ThemeContext } from './ThemeProvider';
import clsx from 'classnames';

export function ThemeToggleButton() {
  const { theme, toggleTheme } = useContext(ThemeContext);

  return (
    <button
      onClick={toggleTheme}
      className={clsx(
        'button',
        theme === 'light' ? 'light-theme' : 'dark-theme',
      )}
      aria-label="Toggle colour scheme"
    >
      {theme === 'light' ? 'DARKEN' : 'LIGHTEN'}
    </button>
  );
}
EOF
ok "ThemeToggleButton.tsx created"

# --------------------------------------------------------
# 6️⃣  Expose Toggle on Landing Page - Header (CORRECTED VERSION)
# --------------------------------------------------------
STEP_PAGE="src/app/page.tsx"
step "Injecting ThemeToggleButton into the demo page header"

# Always inject the import (no check)
sed -i.bak "3i import { ThemeToggleButton } from '@/components/ThemeToggleButton';" "$STEP_PAGE"

# Always inject the component in header (no check)
awk '
  /<header/ { header_open = 1 }
  /<\/header>/ { header_close = 1 }
  /<div style=.*gap.*10px/ { 
    if (header_open && !button_inserted) {
      print $0
      print "          <ThemeToggleButton />"
      button_inserted = 1
      next
    }
  }
  { print }
' "$STEP_PAGE" > "${STEP_PAGE}.tmp" && mv "${STEP_PAGE}.tmp" "$STEP_PAGE"

ok "ThemeToggleButton component injected into header (backup at ${STEP_PAGE}.bak)"

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