# Workstation Connectivity Guide for RAG System

## Introduction

This guide provides step-by-step instructions for setting up and configuring the workstation connectivity layer in your RAG (Retrieval-Augmented Generation) system. The workstation handles all GPU-intensive tasks like LLM inference, text embeddings, and vector search, while your PC handles development, user interface, and local data storage.

## Prerequisites Check and System Verification

Before beginning, let's verify that your system has all necessary components installed and properly configured.

### Check Docker Installation

First, verify Docker is installed and working:

```bash
# Check Docker version
docker --version

# Check if Docker daemon is running
docker info

# Verify Docker can access GPU (if nvidia-docker is installed)
docker run --rm --gpus all nvidia/cuda:11.8.0-runtime-ubuntu20.00 nvidia-smi
```

### Verify NVIDIA Drivers and CUDA

Check if NVIDIA drivers are properly installed:

```bash
# Check NVIDIA driver version
nvidia-smi

# Verify CUDA installation
nvcc --version

# Check if nvidia-container-toolkit is installed
dpkg -l | grep nvidia-container-toolkit
```

### Verify Existing Installations

If you've previously installed components, check versions to avoid conflicts:

```bash
# Check existing Docker version
docker --version

# Check Python version
python3 --version

# Check Node.js version
node --version

# Check if required Python packages are already installed
pip list | grep -E "(fastapi|sentence-transformers|uvicorn|celery|redis|torch|transformers)"
```

## Workstation Setup and Configuration

### Create Workstation Project Directory

```bash
# Create the GPU services directory on your workstation
mkdir -p ~/gpu-services
cd ~/gpu-services
```

### Verify System Resources

Before proceeding, ensure your workstation has sufficient resources:

```bash
# Check available GPU memory
nvidia-smi

# Verify sufficient disk space
df -h

# Check available RAM
free -h
```

### Initialize Project Structure

Create the necessary directories for your GPU services:

```bash
# Create service directories
mkdir -p embedding-service celery-worker

# Create configuration files
touch docker-compose.yml
touch .env
```

## Docker Configuration Implementation

### Workstation Docker Compose Setup

Create the main `docker-compose.yml` file for your GPU services:

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

### Environment Configuration

Create your workstation `.env` file with proper GPU configuration:

```bash
# Create .env file
cat > .env <<'EOF'
# GPU Configuration
CUDA_VISIBLE_DEVICES=0,1,2
MODEL_PATH=/models

# Service configurations
VLLM_MODEL_PATH=/models/gpt-oss-120b
EOF
```

## Service Implementation Details

### Embedding Service Setup

Navigate to the embedding service directory and create the necessary files:

```bash
cd embedding-service
```

Create `Dockerfile`:

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

Create `requirements.txt`:

```txt
fastapi
sentence-transformers
pydantic
uvicorn
```

Create `main.py`:

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

### Celery Worker Setup

Navigate to the celery worker directory:

```bash
cd ../celery-worker
```

Create `Dockerfile`:

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

Create `requirements.txt`:

```txt
celery
redis
torch
transformers
axolotl
```

Create `tasks.py`:

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

## Model Directory Setup

### Create Model Storage Directory

```bash
# Create directory for models
mkdir -p ~/models

# Verify directory creation
ls -la ~/models
```

## Network Configuration and Connectivity

### Test Network Connectivity

Verify that your PC can reach the workstation services:

```bash
# Test embedding service connectivity
curl -X GET http://WORKSTATION_IP:8002/health

# Test Qdrant connectivity
curl -X GET http://WORKSTATION_IP:6333/health

# Test vLLM connectivity
curl -X GET http://WORKSTATION_IP:8001/v1/models
```

### Update PC Environment Configuration

In your PC project's `.env` file, update the workstation connection details:

```bash
# Update your PC .env file
echo 'WORKSTATION_VLLM=http://WORKSTATION_IP:8001/v1' >> .env
echo 'WORKSTATION_QDRANT_HOST=WORKSTATION_IP' >> .env
echo 'WORKSTATION_QDRANT_PORT=6333' >> .env
echo 'WORKSTATION_EMBEDDING=http://WORKSTATION_IP:8002' >> .env
echo 'WORKSTATION_CELERY_BROKER=redis://WORKSTATION_IP:6379/0' >> .env
```

## Service Deployment and Verification

### Start Services

Deploy your GPU services:

```bash
# Start all services
cd ~/gpu-services
docker-compose up -d
```

### Verify Service Status

Check that all services are running properly:

```bash
# Check running containers
docker-compose ps

# View service logs
docker-compose logs

# Check specific service logs
docker-compose logs embedding-service
docker-compose logs vllm
```

### Verify GPU Utilization

Monitor GPU usage to ensure services are using GPU resources:

```bash
# Monitor GPU usage
nvidia-smi -l 1

# Check specific GPU processes
nvidia-smi pmon -c 5
```

## Housekeeping and System Maintenance

### Regular System Checks

Perform routine checks to maintain system health:

```bash
# Check disk space usage
df -h

# Monitor system resources
htop

# Check Docker resource usage
docker stats

# Verify service health
curl -X GET http://localhost:8002/health
curl -X GET http://localhost:6333/health
```

### Cleanup and Optimization

Regular maintenance procedures:

```bash
# Clean up unused Docker images
docker image prune -a

# Clean up stopped containers
docker container prune

# Clean up unused volumes
docker volume prune

# Update Docker images
docker-compose pull
```

### Reinforcement of Key Concepts

**Key Points to Remember:**

1. **Containerization**: All services are containerized with GPU support using `runtime: nvidia`
2. **Volume Mounting**: Models are mounted via volumes for persistence between container restarts
3. **GPU Isolation**: Each service is assigned specific GPU devices via `CUDA_VISIBLE_DEVICES`
4. **Network Separation**: PC handles coordination, workstation handles compute
5. **Resource Management**: Services are configured to use specific GPU resources efficiently

### Troubleshooting Common Issues

```bash
# Issue: Docker can't access GPU
# Solution: Verify nvidia-docker installation
sudo apt-get install nvidia-container-toolkit

# Issue: Connection refused
# Solution: Check firewall settings and service status
docker-compose ps
sudo ufw status

# Issue: GPU memory issues
# Solution: Monitor usage and adjust CUDA_VISIBLE_DEVICES
nvidia-smi
```

## Final Verification

### Complete System Test

Run a final test to ensure everything works:

```bash
# Test the full workflow
# 1. Check all services are running
docker-compose ps

# 2. Verify GPU access
nvidia-smi

# 3. Test API endpoints
curl -X GET http://localhost:8002/health
curl -X GET http://localhost:6333/health

# 4. Confirm connectivity from PC to workstation
# (Test from your PC terminal)
ping WORKSTATION_IP
telnet WORKSTATION_IP 8002
```

### Documentation and Reference

Keep track of your current configuration for future reference:

```bash
# Document current setup
docker-compose config > current-setup.yml

# Save system information
nvidia-smi > gpu-info.txt
docker version > docker-version.txt
```

## Best Practices Summary

1. **Regular Updates**: Keep Docker images and system components updated
2. **Resource Monitoring**: Continuously monitor GPU and memory usage
3. **Backup Strategy**: Regularly backup model files and configurations
4. **Security**: Secure network connections between PC and workstation
5. **Performance Optimization**: Adjust GPU assignments based on workload needs

This guide provides a comprehensive approach to setting up and maintaining the workstation connectivity layer for your RAG system, ensuring proper GPU resource utilization and seamless communication between your PC development environment and workstation compute resources.
