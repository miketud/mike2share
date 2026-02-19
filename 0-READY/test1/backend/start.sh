#!/usr/bin/env bash
set -euo pipefail
source .venv/bin/activate
APP_MODULE="app.main:app"
HOST="0.0.0.0"
PORT="8000"
exec uvicorn $APP_MODULE --reload --host $HOST --port $PORT
