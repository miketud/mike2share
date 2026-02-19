# Complete RAG System Setup Guide

## Introduction

This comprehensive guide provides the complete setup process for a distributed RAG (Retrieval-Augmented Generation) system. The guide starts with the client computer project created by the 0-READY/feb10.sh bootstrap script and extends to the full workstation connectivity layer that enables GPU-accelerated AI processing.

## System Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐
│   Client PC     │    │ Workstation      │
│  (Development)  │    │ (Compute Only)   │
├─────────────────┤    ├──────────────────┤
│  Frontend       │    │  vLLM            │
│  Backend        │    │  Qdrant          │
│  PostgreSQL     │    │  Embedding       │
│  Code Editing   │    │  Celery Worker   │
│  Git Repository │    │  Redis           │
└─────────────────┘    └──────────────────┘
        │                       │
        └───────────────────────┘
                │
        Tailscale VPN or LAN
                │
        ┌──────────────────┐
        │  Network         │
        └──────────────────┘
```

## 1. Client Computer Setup (Using Bootstrap)

### 1.1 Initial Project Creation

The 0-READY/feb10.sh bootstrap script creates the basic project structure:

```bash
# Run the bootstrap script
./feb10.sh

# When prompted, enter your project name
# Example: rag-platform
```

This creates the following structure:

```
~/Projects/rag-platform/
├── frontend/              # Next.js (runs locally :3000)
├── backend/               # FastAPI (runs locally :8000)
│   ├── app/
│   ├── alembic/
│   ├── .venv/
│   ├── requirements.txt
│   └── start.sh
├── docker-compose.yml     # Local services only
├── .env                   # Environment variables
└── README.md
```

### 1.2 Client-Side System Verification

Before proceeding, verify your client system has all necessary components:

```bash
# Check system requirements
docker --version
node --version
python3 --version
nvidia-smi  # This should fail on client (only workstation has GPU)

# Check if required Python packages are installed
pip list | grep -E "(fastapi|uvicorn|sqlalchemy|python-dotenv)"

# Check if required Node packages are installed
cd frontend
pnpm list | grep -E "(next|react|axios)"
```

### 1.3 Client Environment Configuration

Configure your client environment for workstation connectivity:

```bash
# Edit the backend .env file
cd backend
cp .env.example .env

# Update with your workstation IP addresses (these will be configured later)
echo 'WORKSTATION_VLLM=http://WORKSTATION_IP:8001/v1' >> .env
echo 'WORKSTATION_QDRANT_HOST=WORKSTATION_IP' >> .env
echo 'WORKSTATION_QDRANT_PORT=6333' >> .env
echo 'WORKSTATION_EMBEDDING=http://WORKSTATION_IP:8002' >> .env
echo 'WORKSTATION_CELERY_BROKER=redis://WORKSTATION_IP:6379/0' >> .env
echo 'GPU_AVAILABLE=true' >> .env
```

## 2. Workstation Setup

### 2.1 Prerequisites Check

Verify workstation has all required components:

```bash
# Check Docker with NVIDIA support
docker --version
docker info

# Check NVIDIA drivers
nvidia-smi
nvcc --version

# Check if nvidia-container-toolkit is installed
dpkg -l | grep nvidia-container-toolkit

# Check available disk space
df -h

# Check available RAM
free -h
```

### 2.2 Create Workstation Project Directory

```bash
# Create the GPU services directory on workstation
mkdir -p ~/gpu-services
cd ~/gpu-services
```

### 2.3 Initialize Workstation Structure

```bash
# Create service directories
mkdir -p embedding-service celery-worker qdrant_data

# Create configuration files
touch docker-compose.yml
touch .env
```

## 3. Workstation Services Configuration

### 3.1 Workstation Docker Compose Setup

Create the main `docker-compose.yml` file:

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

### 3.2 Environment Configuration

Create workstation `.env` file:

```bash
cat > .env <<'EOF'
# GPU Configuration
CUDA_VISIBLE_DEVICES=0,1,2
MODEL_PATH=/models

# Service configurations
VLLM_MODEL_PATH=/models/gpt-oss-120b
EOF
```

## 4. Embedding Service Implementation

### 4.1 Create Embedding Service Directory

```bash
cd embedding-service
```

### 4.2 Create Service Files

**Dockerfile:**

```dockerfile
FROM nvidia/cuda:11.8.0-runtime-ubuntu20.00

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt .
RUN pip install -r requirements.txt

# Copy application code
COPY . .

# Expose port
EXPOSE 8000

# Run the application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

**requirements.txt:**

```txt
fastapi
sentence-transformers
pydantic
uvicorn
```

**main.py:**

```python
from fastapi import FastAPI
from sentence_transformers import SentenceTransformer
from pydantic import BaseModel

app = FastAPI()

# Load model on GPU at startup
model = SentenceTransformer('BAAI/bge-large-en-v1.5', device='cuda')

class EmbedRequest(BaseModel):
    texts: list[str]
    batch_size: int = 256

@app.post("/encode")
async def encode(request: EmbedRequest):
    embeddings = model.encode(
        request.texts,
        batch_size=request.batch_size,
        show_progress_bar=False,
        convert_to_tensor=True
    )
    return {
        "embeddings": embeddings.cpu().tolist(),
        "model": "bge-large-en-v1.5",
        "dimension": len(embeddings[0])
    }

@app.get("/health")
async def health():
    return {"status": "ready", "gpu": "cuda", "model_loaded": True}
```

## 5. Celery Worker Implementation

### 5.1 Create Celery Worker Directory

```bash
cd ../celery-worker
```

### 5.2 Create Worker Files

**Dockerfile:**

```dockerfile
FROM nvidia/cuda:11.8.0-runtime-ubuntu20.00

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt .
RUN pip install -r requirements.txt

# Copy application code
COPY . .

# Expose port
EXPOSE 8000

# Run the worker
CMD ["celery", "-A", "tasks", "worker", "--loglevel=info"]
```

**requirements.txt:**

```txt
celery
redis
torch
transformers
axolotl
```

**tasks.py:**

```python
# Celery task definitions for fine-tuning
# This is a placeholder - actual implementation would use Axolotl framework for training
from celery import Celery

# Configure Celery
app = Celery('fine_tuning_tasks')
app.config_from_object({
    'broker_url': 'redis://redis:6379/0',
    'result_backend': 'redis://redis:6379/0',
    'task_serializer': 'json',
    'accept_content': ['json'],
    'result_serializer': 'json',
    'timezone': 'UTC',
    'enable_utc': True,
})

@app.task
def fine_tune_model():
    """Placeholder for model fine-tuning task"""
    return "Fine-tuning task completed"
```

## 6. Model Directory Setup

### 6.1 Create Model Storage Directory

```bash
# Create directory for models (on workstation)
mkdir -p ~/models

# Verify directory creation
ls -la ~/models
```

## 7. Network Configuration and Connectivity

### 7.1 Client Configuration

Update the client's `.env` file with actual workstation IP addresses:

```bash
# In your client project backend directory
cd ~/Projects/rag-platform/backend

# Update with actual workstation IP (replace WORKSTATION_IP with actual IP)
echo 'WORKSTATION_VLLM=http://192.168.1.100:8001/v1' >> .env
echo 'WORKSTATION_QDRANT_HOST=192.168.1.100' >> .env
echo 'WORKSTATION_EMBEDDING=http://192.168.1.100:8002' >> .env
echo 'WORKSTATION_CELERY_BROKER=redis://192.168.1.100:6379/0' >> .env
```

### 7.2 Test Network Connectivity

**From Client Computer:**

```bash
# Test connectivity to workstation services
curl -X GET http://WORKSTATION_IP:8002/health
curl -X GET http://WORKSTATION_IP:6333/health
curl -X GET http://WORKSTATION_IP:8001/v1/models

# Test basic network connectivity
ping WORKSTATION_IP
telnet WORKSTATION_IP 8002
```

**From Workstation:**

```bash
# Test that services are running
docker-compose ps

# Test individual service health
curl -X GET http://localhost:8002/health
curl -X GET http://localhost:6333/health
```

## 8. Service Deployment and Verification

### 8.1 Start Workstation Services

```bash
# On workstation
cd ~/gpu-services
docker-compose up -d
```

### 8.2 Verify Workstation Services

```bash
# Check all services are running
docker-compose ps

# View service logs
docker-compose logs

# Monitor GPU usage
nvidia-smi -l 1
```

### 8.3 Verify Client Connectivity

```bash
# From client computer, test API connectivity
cd ~/Projects/rag-platform

# Test that client can reach workstation
curl -X GET http://WORKSTATION_IP:8002/health
curl -X GET http://WORKSTATION_IP:6333/health
```

## 9. Complete System Testing

### 9.1 End-to-End Test

Run a complete workflow test:

```bash
# 1. Start client services (if not already running)
cd ~/Projects/rag-platform
docker-compose up -d

# 2. Verify workstation services are running
cd ~/gpu-services
docker-compose ps

# 3. Test API endpoints
curl -X GET http://WORKSTATION_IP:8002/health
curl -X GET http://WORKSTATION_IP:6333/health

# 4. Test client-to-workstation connectivity
# (Run this from client terminal)
curl -X GET http://WORKSTATION_IP:8002/encode -H "Content-Type: application/json" -d '{"texts": ["test"], "batch_size": 1}'
```

### 9.2 Resource Monitoring

Monitor system resources during operation:

```bash
# Client monitoring
htop
docker stats

# Workstation monitoring
nvidia-smi -l 1
df -h
free -h
```

## 10. Housekeeping and Maintenance

### 10.1 Regular System Checks

```bash
# Check disk space usage
df -h

# Monitor system resources
htop

# Check Docker resource usage
docker stats

# Verify service health
curl -X GET http://WORKSTATION_IP:8002/health
curl -X GET http://WORKSTATION_IP:6333/health
```

### 10.2 Cleanup and Optimization

```bash
# Clean up unused Docker images (on workstation)
docker image prune -a

# Clean up stopped containers (on workstation)
docker container prune

# Clean up unused volumes (on workstation)
docker volume prune

# Update Docker images (on workstation)
docker-compose pull
```

### 10.3 Backup and Recovery

```bash
# Backup model files (on workstation)
tar -czf models-backup-$(date +%Y%m%d).tar.gz ~/models

# Backup database (on client)
pg_dump -U user ragdb > db-backup-$(date +%Y%m%d).sql

# Document current setup
docker-compose config > current-setup.yml
```

## 11. Troubleshooting Common Issues

### 11.1 Docker GPU Access Issues

```bash
# Check nvidia-docker installation
sudo apt-get install nvidia-container-toolkit

# Restart Docker daemon
sudo systemctl restart docker

# Test GPU access
docker run --rm --gpus all nvidia/cuda:11.8.0-runtime-ubuntu20.00 nvidia-smi
```

### 11.2 Network Connectivity Issues

```bash
# Check firewall settings
sudo ufw status

# Test specific ports
telnet WORKSTATION_IP 8002
telnet WORKSTATION_IP 6333

# Check Docker port mappings
docker-compose ps
```

### 11.3 Service Health Issues

```bash
# Check service logs
docker-compose logs embedding-service
docker-compose logs vllm

# Restart specific service
docker-compose restart embedding-service

# View service status
docker-compose ps
```

## 12. Best Practices Summary

### 12.1 Client-Side Best Practices

1. **Environment Management**: Keep workstation connection details in `.env` files
2. **Fallback Mechanisms**: Implement CPU fallback when GPU unavailable
3. **Security**: Secure network connections between client and workstation
4. **Monitoring**: Regularly monitor service health and resource usage

### 12.2 Workstation Best Practices

1. **Resource Isolation**: Assign specific GPU devices to services
2. **Volume Management**: Use persistent volumes for model storage
3. **Container Management**: Regular cleanup of unused images and containers
4. **Performance Optimization**: Monitor GPU utilization and adjust configurations

### 12.3 System Maintenance

1. **Regular Updates**: Keep Docker images and system components updated
2. **Backup Strategy**: Regularly backup model files and configurations
3. **Monitoring**: Continuous monitoring of GPU and system resources
4. **Documentation**: Keep track of current configurations for future reference

## 13. Complete Workflow Diagram

```
1. Client PC (Development)
   ↓
2. Frontend (Next.js) → http://localhost:3000
   ↓
3. Backend (FastAPI) → http://localhost:8000
   ↓
4. API Calls to Workstation Services
   ↓
5. Workstation (GPU Compute)
   │
   ├── vLLM → LLM Inference (port 8001)
   ├── Qdrant → Vector Search (port 6333)
   ├── Embedding Service → Text Embeddings (port 8002)
   └── Celery Worker → Fine-tuning (via Redis)
   ↓
6. Results returned to Client
   ↓
7. Frontend displays results to user
```

This guide provides a complete, end-to-end setup for the distributed RAG system, starting with the client computer project created by the bootstrap script and extending to full workstation connectivity. The bootstrap remains unchanged, but this guide shows exactly how to add the additional tooling and configuration needed for a complete RAG system.
