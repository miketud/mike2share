# Docker Compose Setup Guide

This guide explains how to create and use Docker Compose files to set up services like PostgreSQL databases. I'll walk through a complete example with explanations for each line.

## What you need to have installed:



## Basic Docker Compose Structure

```yaml
version: "3.8"          ## Specifies the Docker Compose file format version. Version 3.8 is widely supported and provides good features.
## Services
services:               ## Defines the list of containers to run
  postgres:             ## Name of the service
    image: postgres:15  ## Pulls the PostgreSQL 15 image from Docker Hub
## Environment Variables
environment:                                        ## Sets environment variables inside the container; uses ${VAR:-default} syntax = uses environment variable or default value if not set
  POSTGRES_DB: ${POSTGRES_DB:-postgres}             ## Database name (defaults to "postgres")
  POSTGRES_USER: ${POSTGRES_USER:-postgres}         ## Database user (defaults to "postgres")
  POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-password} ## Database pass (defaults to "password")
## Port Mapping
ports:                              ## Maps container ports to host ports
  - "${POSTGRES_PORT:-5432}:5432"   ## Host port:Container port; Host port uses POSTGRES_PORT env var or defaults to 5432; Container port is always 5432 (the standard PostgreSQL port)
                                    ## If your Windows PostgreSQL server is already running on port 5432, you should change the Docker container's port mapping to avoid conflicts: "${POSTGRES_PORT:-5433}:5432" 

## Data Persistence
volumes:                                    ## Mounts directories between host and container
  - postgres_data:/var/lib/postgresql/data  ## Named volume mapping - ensures database data persists even when container stops
## Restart Policy
restart: unless-stopped                     ## Defines when to restart the container; unless-stopped = container will automatically restart unless stopped manually
## Volumes Section
volumes:                ## Defines named volumes for data persistence
  postgres_data:        ## Creates a named volume (automatically managed by Docker), in this case it is called "postgres_data"
## Complete Working Example

Here's a complete minimal PostgreSQL Docker Compose file:

```yaml
version: "3.8"

services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: myapp_db
      POSTGRES_USER: myapp_user
      POSTGRES_PASSWORD: myapp_password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped

volumes:
  postgres_data:
```

## Usage Examples

### 1. Basic Startup

```bash
# Start the service
docker-compose up -d postgres

# Stop the service
docker-compose down
```

### 2. Custom Port

```bash
# Use custom host port
POSTGRES_PORT=5433 docker-compose up -d postgres
```

### 3. Custom Environment

```bash
# Set custom environment variables
POSTGRES_DB=myproject POSTGRES_USER=admin POSTGRES_PASSWORD=secret docker-compose up -d postgres
```

## Key Concepts

1. **Host vs Container Ports**: `host:container` mapping
2. **Environment Variables**: Flexible configuration with defaults
3. **Named Volumes**: Data persistence between container restarts
4. **Restart Policies**: Automatic recovery from failures
5. **Services**: Each service runs in its own container

This structure can be extended for more complex setups with multiple services, networks, and advanced configurations.

## Advanced Features

### Healthchecks

```yaml
healthcheck:
  test:
    [
      "CMD-SHELL",
      "pg_isready -U ${POSTGRES_USER:-postgres} -d ${POSTGRES_DB:-postgres}",
    ]
  interval: 30s
  timeout: 10s
  retries: 3
```

**What it means:**

- `healthcheck:` - Defines container health check
- `test:` - Command to run for health check
- `interval:` - How often to check (30 seconds)
- `timeout:` - Maximum time to wait for check
- `retries:` - Number of failures before marking unhealthy

### Initialization Scripts

```yaml
volumes:
  - postgres_data:/var/lib/postgresql/data
  - ./init-scripts:/docker-entrypoint-initdb.d
```

**What it means:**

- Mounts a local directory with SQL scripts to run on first container startup
- Scripts in `/docker-entrypoint-initdb.d` are executed automatically

## Workstation Docker Setup

### Overview

In a RAG system architecture, Docker is used in two distinct environments:

1. **Client PC**: Local development environment with PostgreSQL database
2. **Workstation**: Remote compute environment with all GPU-accelerated services

### Client PC Docker Setup

This is the setup for your local development environment:

```yaml
version: "3.8"

services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: ${POSTGRES_DB:-ragdb}
      POSTGRES_USER: ${POSTGRES_USER:-raguser}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-ragpass}
    ports:
      - "${POSTGRES_PORT:-5432}:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init-scripts:/docker-entrypoint-initdb.d
    restart: unless-stopped
    healthcheck:
      test:
        [
          "CMD-SHELL",
          "pg_isready -U ${POSTGRES_USER:-raguser} -d ${POSTGRES_DB:-ragdb}",
        ]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  postgres_data:
```

### Workstation Docker Setup

For your workstation (remote compute), you would typically have a separate docker-compose.yml file in `~/gpu-services/` that looks like this:

```yaml
version: "3.8"

services:
  vllm:
    image: vllm/vllm-openai:latest
    runtime: nvidia
    environment:
      - CUDA_VISIBLE_DEVICES=1,2
    command: >
      --model /models/gpt-oss-120b
      --tensor-parallel-size 2
      --host 0.0.0.0
      --port 8000
    ports:
      - "8001:8000"
    volumes:
      - /home/you/models:/models
    restart: unless-stopped

  embedding-service:
    build: ./embedding-service
    runtime: nvidia
    environment:
      - CUDA_VISIBLE_DEVICES=1
    ports:
      - "8002:8000"
    volumes:
      - /home/you/models:/models
    restart: unless-stopped

  qdrant:
    image: qdrant/qdrant:latest
    ports:
      - "6333:6333"
    volumes:
      - ./qdrant_data:/qdrant/storage
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    restart: unless-stopped

  celery-worker:
    build: ./celery-worker
    runtime: nvidia
    environment:
      - CUDA_VISIBLE_DEVICES=2
      - CELERY_BROKER_URL=redis://redis:6379/0
    depends_on:
      - redis
    volumes:
      - /home/you/models:/models
    restart: unless-stopped
```

**Key Points for Workstation Setup:**

- Services run on the workstation with GPU support (`runtime: nvidia`)
- Model paths are mapped from the workstation's model directory (`/home/you/models:/models`)
- Services communicate via network connections (not Docker networks)
- Port mappings for external access (8001, 8002, 6333, 6379)
- Uses existing model files like your vllm setup with `~/models` directory

This comprehensive guide provides everything you need to understand and create Docker Compose files for your projects.
