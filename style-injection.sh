#!/usr/bin/env bash
# --------------------------------------------------------
# style-injection.sh
#   Runs after the full‑stack bootstrap (boot-10.sh)
#   • Updates globals.css with light/dark CSS variables
#   • Rewrites layout.tsx to wrap the app in ThemeProvider
#   • Adds ThemeProvider.tsx and ThemeToggleButton.tsx
# --------------------------------------------------------
set -euo pipefail

# --------------------------------------------------------
# Helper – pretty output (re‑uses the colour functions from boot‑10.sh)
# --------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; NC='\033[0m'
step() { printf "${BLUE}▶${NC} %s\n" "$1"; }
ok()   { printf "${GREEN}✔${NC} %s\n" "$1"; }
warn() { printf "${YELLOW}⚠${NC} %s\n" "$1"; }

# --------------------------------------------------------
# 1️⃣  Determine script location (the “main” folder)
# --------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --------------------------------------------------------
# 2️⃣  Find sibling project directories (must contain a frontend/ folder)
# --------------------------------------------------------
candidates=()
for d in "$SCRIPT_DIR"/*/; do
  [[ "$d" =~ /\./ ]] && continue                # skip hidden dirs
  [[ -d "$d/frontend" ]] && candidates+=( "$(basename "$d")" )
done

# --------------------------------------------------------
# 3️⃣  Abort if no projects found
# --------------------------------------------------------
if (( ${#candidates[@]} == 0 )); then
  printf "${RED}✖ No project directories with a frontend/ found next to %s${NC}\n" "$(basename "$0")"
  exit 1
fi

# --------------------------------------------------------
# 4️⃣  Prompt user to select a project (number or name)
# --------------------------------------------------------
echo "Available projects:"
for i in "${!candidates[@]}"; do
  printf "  %2d) %s\n" $((i+1)) "${candidates[i]}"
done

while true; do
  read -rp "Select a project by number or type its name: " choice

  # Numeric selection?
  if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice > 0 && choice <= ${#candidates[@]} )); then
    PROJECT_NAME="${candidates[choice-1]}"
    break
  fi

  # Typed name – verify it exists and looks like a project
  if [[ -d "$SCRIPT_DIR/$choice/frontend" ]]; then
    PROJECT_NAME="$choice"
    break
  fi

  echo -e "${YELLOW}⚠ Invalid choice – try again${NC}"
done

# --------------------------------------------------------
# 5️⃣  Resolve the project root and export variables expected by the original script
# --------------------------------------------------------
PROJECT_ROOT="${SCRIPT_DIR}/${PROJECT_NAME}"
export PROJECT_ROOT PROJECT_NAME

echo -e "${BLUE}▶${NC} Selected project: $PROJECT_NAME"
echo -e "${BLUE}▶${NC} Project root:   $PROJECT_ROOT"

# --------------------------------------------------------
# 6️⃣  Move into the project's frontend folder (as the original script did)
# --------------------------------------------------------
cd "$PROJECT_ROOT/frontend"

# ----------------------------------------------------------------
# The rest of the script is the original *apply-theme.sh* logic.
# ----------------------------------------------------------------

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
import { GeistSans } from 'geist/font/sans'
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
      <body className={GeistSans.className}>
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
        'p-2 rounded',
        theme === 'dark' ? 'bg-gray-800 text-white' : 'bg-gray-200 text-black',
      )}
      aria-label="Toggle colour scheme"
    >
      {theme === 'dark' ? '☀️ Light' : '🌙 Dark'}
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
  sed -i.bak '1i import { ThemeToggleButton } from "@/components/ThemeToggleButton";' "$STEP_PAGE"
  # Append the component just before the closing </main>
  awk '
    /<\/main>/ && !found {
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