# Docker Compose Setup Guide

This guide explains how to create and use Docker Compose files to set up services like PostgreSQL databases. I'll walk through a complete example with explanations for each line.

## Basic Docker Compose Structure

```yaml
version: "3.8"
```

**What it means:** Specifies the Docker Compose file format version. Version 3.8 is widely supported and provides good features.

## Services Section

```yaml
services:
  postgres:
    image: postgres:15
```

**What it means:**

- `services:` - Defines the list of containers to run
- `postgres:` - Name of this service (used for referencing)
- `image: postgres:15` - Pulls the PostgreSQL 15 image from Docker Hub

## Environment Variables

```yaml
environment:
  POSTGRES_DB: ${POSTGRES_DB:-postgres}
  POSTGRES_USER: ${POSTGRES_USER:-postgres}
  POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-password}
```

**What it means:**

- `environment:` - Sets environment variables inside the container
- `${VAR:-default}` - Uses environment variable or default value if not set
- `POSTGRES_DB` - Database name (defaults to "postgres")
- `POSTGRES_USER` - Database user (defaults to "postgres")
- `POSTGRES_PASSWORD` - Database password (defaults to "password")

## Port Mapping

```yaml
ports:
  - "${POSTGRES_PORT:-5432}:5432"
```

**What it means:**

- `ports:` - Maps container ports to host ports
- `"${POSTGRES_PORT:-5432}:5432"` - Host port:Container port
- Host port (left): Uses `POSTGRES_PORT` env var or defaults to 5432
- Container port (right): Always 5432 (PostgreSQL standard port)

## Data Persistence

```yaml
volumes:
  - postgres_data:/var/lib/postgresql/data
```

**What it means:**

- `volumes:` - Mounts directories between host and container
- `postgres_data:/var/lib/postgresql/data` - Named volume mapping
- This ensures database data persists even when container stops

## Restart Policy

```yaml
restart: unless-stopped
```

**What it means:**

- `restart:` - Defines when to restart the container
- `unless-stopped` - Restart unless manually stopped

## Volumes Section

```yaml
volumes:
  postgres_data:
```

**What it means:**

- `volumes:` - Defines named volumes for data persistence
- `postgres_data:` - Creates a named volume (automatically managed by Docker)

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

This comprehensive guide provides everything you need to understand and create Docker Compose files for your projects.
