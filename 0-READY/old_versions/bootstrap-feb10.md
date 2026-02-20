# bootstrap-feb10.sh - Full-Stack Bootstrap Script

A Bash script that automates the setup of a production-ready full-stack application using Next.js (frontend) and FastAPI (backend).

## Architecture

```
.
├── backend/          # FastAPI Python API
├── frontend/         # Next.js 15 React application
└── .gitignore
```

## Backend Tooling (Python 3.12)

### Core Framework

| Tool       | Purpose                                                |
| ---------- | ------------------------------------------------------ |
| FastAPI    | High-performance async API with automatic OpenAPI docs |
| Uvicorn    | Lightning-fast ASGI server with hot reload             |
| SQLAlchemy | Powerful ORM with async support                        |
| Alembic    | Database migrations with version control               |
| Pydantic   | Runtime type validation and settings management        |

### Development Tools

| Tool                    | Purpose                                                |
| ----------------------- | ------------------------------------------------------ |
| pytest + pytest-asyncio | Async test suite with coverage                         |
| Ruff                    | Fast Python linter (replaces Flake8, isort, pyupgrade) |
| Black                   | Opinionated code formatter                             |
| Mypy                    | Static type checking                                   |
| pre-commit              | Git hooks for quality checks                           |

### Utilities

| Tool          | Purpose                           |
| ------------- | --------------------------------- |
| python-dotenv | Environment variable management   |
| structlog     | Structured logging                |
| tenacity      | Retry logic for external services |
| httpx         | Modern HTTP client for testing    |

## Frontend Tooling (Next.js 15 + TypeScript)

### Framework & Routing

| Tool       | Purpose                                       |
| ---------- | --------------------------------------------- |
| Next.js 15 | React framework with App Router, SSR, and RSC |
| TypeScript | Type-safe development                         |
| React 19   | Latest React features                         |

### State & Data Fetching

| Tool           | Purpose                                                 |
| -------------- | ------------------------------------------------------- |
| TanStack Query | Declarative data fetching, caching, and synchronization |
| Zustand        | Lightweight state management (3kb)                      |
| Axios          | HTTP client with interceptors                           |

### Styling & Animation

| Tool            | Purpose                                        |
| --------------- | ---------------------------------------------- |
| Vanilla Extract | Type-safe CSS-in-JS with zero runtime          |
| Framer Motion   | Production-grade animations                    |
| GSAP            | Advanced timeline-based animations             |
| next-themes     | Light/dark mode with system preference support |

### UI Utilities

| Tool           | Purpose                                                |
| -------------- | ------------------------------------------------------ |
| classnames     | Conditional className composition                      |
| dayjs          | Lightweight date manipulation (2kb vs 66kb for Moment) |
| lottie-react   | High-quality animations                                |
| react-icons    | Icon library                                           |
| react-markdown | Markdown rendering                                     |
| react-use      | Essential React hooks collection                       |
| Lenis          | Smooth scroll library                                  |
| howler         | Web audio management                                   |

### Testing & Quality

| Tool                         | Purpose               |
| ---------------------------- | --------------------- |
| Jest + React Testing Library | Component testing     |
| jest-axe                     | Accessibility testing |
| Prettier                     | Code formatting       |
| Stylelint                    | CSS/SCSS linting      |

## Package Managers

| Tool  | Purpose                                                             |
| ----- | ------------------------------------------------------------------- |
| uv    | Fast Python package installer (Rust-based, 50-100x faster than pip) |
| pnpm  | Fast, disk-efficient Node package manager (2-3x faster than npm)    |
| nvm   | Node.js version management                                          |
| pyenv | Python version management                                           |

## System Requirements

| Tool                                              | Purpose                                      |
| ------------------------------------------------- | -------------------------------------------- |
| PostgreSQL client                                 | Database connection tools                    |
| build-essential (Linux) / Xcode CLI Tools (macOS) | Compilers for native extensions              |
| Git                                               | Version control with main branch initialized |
