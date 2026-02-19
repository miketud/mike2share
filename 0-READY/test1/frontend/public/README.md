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
