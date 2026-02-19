# Structured RAG System Setup Guide

## System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        CLIENT PC (Development)                  │
├─────────────────────────────────────────────────────────────────┤
│  • Frontend (Next.js)        :3000                              │
│  • Backend (FastAPI)         :8000                              │
│  • PostgreSQL                :5432                              │
│  • Code Editing                                                 │
│  • Git Repository                                               │
│  • Development Tools                                            │
└─────────────────────────────────────────────────────────────────┘
                              │
                      ┌───────┴───────┐
                      │               │
                     Tailscale VPN or LAN
                      │               │
┌─────────────────────────────────────────────────────────────────┐
│                     WORKSTATION (Compute Only)                  │
├─────────────────────────────────────────────────────────────────┤
│  • vLLM                      :8001                              │
│  • Qdrant                    :6333                              │
│  • Embedding Service         :8002                              │
│  • Celery Worker             (background)                       │
│  • Redis                     :6379                              │
│                                                                 │
│  • File Storage              ~/gpu-services/file_storage/       │
│  • Model Storage             ~/gpu-services/models/             │
│  • Vector Database           Qdrant                             │
│                                                                 │
│  • All GPU/CPU Tasks                                            │
│  • No User Data Storage (except vectors)                        │
└─────────────────────────────────────────────────────────────────┘
```

## PC (Client) Responsibilities

### 1. Setup and Configuration

```bash
# Run the bootstrap script to create project structure
./bootstrap-feb10.sh

# When prompted, enter your project name
# Example: rag-platform
```

### 2. Client-Side Services

```bash
# Start local PostgreSQL database
docker-compose up -d postgres

# Start local backend API
cd backend
./start.sh

# Start local frontend
cd frontend
pnpm dev
```

### 3. Client-Workstation Connectivity

```bash
# Configure workstation connection details in backend/.env
echo 'WORKSTATION_VLLM=http://WORKSTATION_IP:8001/v1' >> .env
echo 'WORKSTATION_QDRANT_HOST=WORKSTATION_IP' >> .env
echo 'WORKSTATION_EMBEDDING=http://WORKSTATION_IP:8002' >> .env
echo 'WORKSTATION_CELERY_BROKER=redis://WORKSTATION_IP:6379/0' >> .env
```

### 4. PC System Verification

```bash
# Check client system requirements
docker --version
node --version
python3 --version

# Verify client can reach workstation
ping WORKSTATION_IP
curl -X GET http://WORKSTATION_IP:8002/health
```

## 🖥️ Workstation Responsibilities

### 1. Prerequisites Check

```bash
# Check Docker with NVIDIA support
docker --version
docker info

# Check NVIDIA drivers
nvidia-smi
nvcc --version

# Check system resources
df -h  # Disk space
free -h  # RAM
```

### 2. Workstation Setup

```bash
# Create GPU services directory
mkdir -p ~/gpu-services
cd ~/gpu-services

# Create service directories
mkdir -p embedding-service celery-worker qdrant_data file_storage models
```

### 3. Workstation Services Configuration

```yaml
# ~/gpu-services/docker-compose.yml
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

### 4. Workstation File Storage Setup

```bash
# Create file storage directory
mkdir -p ~/gpu-services/file_storage

# Verify storage setup
ls -la ~/gpu-services/file_storage
```

### 5. Workstation Service Deployment

```bash
# Start all workstation services
cd ~/gpu-services
docker-compose up -d

# Verify services are running
docker-compose ps
```

## 🔄 Data Flow and Processing

### 1. File Upload Process

```
PC (Client) → Upload File → PC Backend (FastAPI)
           ↓
PC Backend → Send File Path to Workstation Storage
           ↓
PC Backend → Send Processing Request to Workstation Services
           ↓
Workstation → ALL Processing (Parse, Chunk, Embed, Store in Qdrant)
           ↓
PC Backend → Receive Results → Store Metadata in PostgreSQL
```

### 2. Query Processing

```
PC (Client) → User Query → PC Backend
           ↓
PC Backend → Send Query to Workstation Embedding Service
           ↓
Workstation → Generate Query Vector → Search Qdrant
           ↓
Workstation → Return Vector IDs → PC Backend
           ↓
PC Backend → Get Chunk Metadata from PostgreSQL
           ↓
PC Backend → Build Context → Send to Workstation LLM
           ↓
Workstation → Generate Answer → Return to PC Backend
           ↓
PC Backend → Store Query Log in PostgreSQL
           ↓
PC (Client) → Display Results
```

## 🛠️ Workstation Service Implementation

### 1. Embedding Service

```bash
# Create embedding service directory
cd ~/gpu-services/embedding-service

# Create Dockerfile
FROM nvidia/cuda:11.8.0-runtime-ubuntu20.00

WORKDIR /app
RUN apt-get update && apt-get install -y python3 python3-pip
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

```txt
# requirements.txt
fastapi
sentence-transformers
pydantic
uvicorn
```

```python
# main.py
from fastapi import FastAPI
from sentence_transformers import SentenceTransformer
from pydantic import BaseModel

app = FastAPI()
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

### 2. Celery Worker

```bash
# Create celery worker directory
cd ~/gpu-services/celery-worker

# Create Dockerfile
FROM nvidia/cuda:11.8.0-runtime-ubuntu20.00

WORKDIR /app
RUN apt-get update && apt-get install -y python3 python3-pip
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
EXPOSE 8000
CMD ["celery", "-A", "tasks", "worker", "--loglevel=info"]
```

```txt
# requirements.txt
celery
redis
torch
transformers
axolotl
```

```python
# tasks.py
from celery import Celery

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
    return "Fine-tuning task completed"
```

## 🔍 System Verification

### 1. PC Verification

```bash
# Test client connectivity
curl -X GET http://WORKSTATION_IP:8002/health
curl -X GET http://WORKSTATION_IP:6333/health

# Test database connectivity
psql -h localhost -U raguser -d ragdb
```

### 2. Workstation Verification

```bash
# Test workstation services
docker-compose ps

# Test individual service health
curl -X GET http://localhost:8002/health
curl -X GET http://localhost:6333/health

# Monitor GPU usage
nvidia-smi -l 1
```

## 🧹 Maintenance and Cleanup

### 1. PC Maintenance

```bash
# Regular database checks
docker-compose ps postgres
psql -c "SELECT COUNT(*) FROM documents;"

# Client cleanup
docker-compose down
```

### 2. Workstation Maintenance

```bash
# Regular cleanup
docker image prune -a
docker container prune
docker volume prune

# Monitor resources
docker stats
nvidia-smi
df -h
```

## 📊 Resource Management

### 1. GPU Resource Allocation

```bash
# Workstation GPU configuration
CUDA_VISIBLE_DEVICES=0,1,2  # Assign specific GPUs to services
```

### 2. Storage Management

```
Workstation Storage Structure:
~/gpu-services/
├── file_storage/        # Raw uploaded files
├── models/              # Model files
├── qdrant_data/         # Qdrant vector storage
└── embedding-service/   # Service code
```

## 🚨 Troubleshooting

### 1. Common Issues

```bash
# Docker GPU access
sudo apt-get install nvidia-container-toolkit
sudo systemctl restart docker

# Network connectivity
ping WORKSTATION_IP
telnet WORKSTATION_IP 8002

# Service health
docker-compose logs embedding-service
docker-compose logs vllm
```

### 2. Performance Optimization

```bash
# Monitor GPU usage
nvidia-smi -l 1

# Check resource usage
docker stats

# Optimize batch sizes
# Adjust batch_size in embedding requests
```

## ✅ Best Practices

### 1. Security

- Keep sensitive data on PC, vectors on workstation
- Use secure network connections (VPN)
- Regular backup of PostgreSQL database

### 2. Performance

- Monitor GPU utilization
- Optimize batch processing
- Implement asynchronous file handling

### 3. Maintenance

- Regular system checks
- Backup model files
- Update Docker images periodically

## 📋 Summary

### PC Responsibilities:

- ✅ User interface and application logic
- ✅ PostgreSQL database management
- ✅ API orchestration
- ✅ Network connectivity to workstation
- ✅ Development and testing

### Workstation Responsibilities:

- ✅ All GPU/CPU processing
- ✅ File storage and management
- ✅ Vector database (Qdrant)
- ✅ Model storage and serving
- ✅ Background task processing (Celery)

This architecture provides a clean separation where the PC handles development and user interaction while the workstation handles all compute-intensive tasks, making it efficient, scalable, and secure.
