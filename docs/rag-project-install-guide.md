# RAG Project Installation Guide

_A Beginner's First-Person Perspective_

---

## Welcome! Installing Your First RAG Project

Hey there! If you're reading this, you're about to install your very own **RAG** (Retrieval-Augmented Generation) system. Don't worry - I'll walk you through this step by step like you're a complete beginner. This is going to be an exciting journey where you'll set up a powerful AI system that can understand and answer questions about your documents.

Let me tell you what we're building: We'll have two computers working together - one for development (your PC) and one for heavy computing (the workstation). Your PC will handle all the coding, user interface, and data storage, while the workstation will do all the heavy GPU work like understanding text and generating answers.

---

## Prerequisites: What You Need First

Before we start, make sure you have these tools installed on your PC:

- **Git** (for version control)
- **Docker Desktop** (for containerization)
- **Node.js** (for the frontend)
- **Python 3.8+** (for the backend)

If you don't have these, install them now. Docker Desktop is especially important because it's what will let us run all these services together.

---

## Step 1: Setting Up Your Development Environment

Okay, let's start with your PC. Open your terminal and let's create our project directory:

```bash
mkdir ~/Projects
cd ~/Projects
mkdir rag-platform
cd rag-platform
```

Now let's initialize our Git repository:

```bash
git init
```

This creates our main project folder where all our development work will happen.

---

## Step 2: Creating the PC Project Structure

Let's create all the directories we'll need:

```bash
mkdir frontend backend
touch docker-compose.yml
touch .env
touch README.md
```

The structure will look like this:

```
~/Projects/rag-platform/
├── frontend/              # Your web interface
├── backend/               # Your Python application
├── docker-compose.yml     # How to start services
├── .env                   # Configuration settings
└── README.md              # Project documentation
```

---

## Step 3: Setting Up Your Frontend (Next.js)

Let's start with the frontend. This is where users will interact with your system:

```bash
cd frontend
npm init -y
npm install next react react-dom
```

This creates a basic Next.js application. Next.js is a powerful framework that makes building web interfaces easy.

---

## Step 4: Setting Up Your Backend (FastAPI)

Now let's move to the backend - this is where all the AI magic happens:

```bash
cd ../backend
pip install fastapi uvicorn python-dotenv sqlalchemy
```

FastAPI is a modern, fast (high-performance) web framework for building APIs with Python 3.7+ based on standard Python type hints.

---

## Step 5: The Workstation Side - Getting Ready

Now comes the tricky part - setting up your workstation. This is where all the heavy GPU computing will happen.

First, make sure your workstation has:

- **NVIDIA drivers** installed
- **Docker with NVIDIA Container Toolkit**
- **CUDA toolkit**

If you're on Linux, you can install these with:

```bash
# Install NVIDIA drivers
sudo apt update
sudo apt install nvidia-driver-535

# Install Docker with NVIDIA support
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
sudo apt update
sudo apt install nvidia-container-toolkit
```

---

## Step 6: Creating the Workstation Project Structure

On your workstation, create the GPU services directory:

```bash
mkdir ~/gpu-services
cd ~/gpu-services
mkdir embedding-service celery-worker
touch docker-compose.yml
touch .env
```

The structure will look like this:

```
~/gpu-services/
├── docker-compose.yml     # GPU service orchestration
├── embedding-service/     # Text embedding service
├── celery-worker/         # Fine-tuning task worker
└── .env                   # Workstation configuration
```

---

## Step 7: Installing Core GPU Services

Let's install the main services that will do all the AI work:

### Installing vLLM (Large Language Model)

This is where your AI will generate answers:

```bash
# On workstation, create a directory for models
mkdir -p ~/models
```

vLLM is a fast and easy-to-use LLM serving framework that will run your large language models.

### Installing Qdrant (Vector Database)

This stores all your document embeddings:

```bash
# Qdrant will be installed via Docker
```

Qdrant is a vector search engine that makes finding relevant information fast and efficient.

### Installing Redis (Task Queue)

This manages background tasks:

```bash
# Redis will be installed via Docker
```

Redis handles all the background work like fine-tuning models.

---

## Step 8: Setting Up the Embedding Service

This is where text gets converted to numbers that AI can understand:

```bash
cd ~/gpu-services/embedding-service
pip install fastapi sentence-transformers pydantic uvicorn
```

The embedding service uses sentence-transformers, a powerful library that converts text into mathematical vectors.

---

## Step 9: Creating the Celery Worker

This handles all the model fine-tuning work:

```bash
cd ~/gpu-services/celery-worker
pip install celery redis torch transformers axolotl
```

Celery is a distributed task queue system that makes it easy to run background jobs.

---

## Step 10: Configuring Environment Variables

This is where you tell your system how to connect to the workstation:

```bash
# On your PC, edit .env file
echo 'DATABASE_URL=postgresql://user:pass@localhost:5432/ragdb' >> .env
echo 'FRONTEND_URL=http://localhost:3000' >> .env
echo 'WORKSTATION_VLLM=http://100.x.x.x:8001/v1' >> .env
echo 'WORKSTATION_QDRANT_HOST=100.x.x.x' >> .env
echo 'WORKSTATION_EMBEDDING=http://100.x.x.x:8002' >> .env
echo 'GPU_AVAILABLE=true' >> .env
```

---

## Step 11: Docker Configuration

Now comes the magic - Docker configuration. This is what will make everything work together.

### PC Docker Compose

```yaml
version: "3.8"
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: raguser
      POSTGRES_PASSWORD: dev
      POSTGRES_DB: ragdb
    ports:
      - "5432:5432"
    volumes:
      - ./data/postgres:/var/lib/postgresql/data

  backend:
    build: ./backend
    ports:
      - "8000:8000"
    volumes:
      - ./backend:/app
    env_file: .env
    depends_on:
      - postgres
    command: uvicorn main:app --reload --host 0.0.0.0 --port 8000

  frontend:
    build: ./frontend
    ports:
      - "3000:3000"
    volumes:
      - ./frontend:/app
      - /app/node_modules
    environment:
      - NEXT_PUBLIC_API_URL=http://localhost:8000
    command: npm run dev
```

### Workstation Docker Compose

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

---

## Step 12: Testing Your Setup

Let's test if everything works:

### Start Your PC Services

```bash
cd ~/Projects/rag-platform
docker-compose up -d
```

This starts your PostgreSQL database, backend API, and frontend interface.

### Start Your Workstation Services

```bash
cd ~/gpu-services
docker-compose up -d
```

This starts all your GPU services: vLLM, Qdrant, embedding service, etc.

---

## Step 13: The First Test

Open your browser and go to:

- **Frontend**: http://localhost:3000
- **Backend API docs**: http://localhost:8000/docs

You should see your beautiful web interface and API documentation. If you can see these, congratulations! You've successfully installed the RAG system.

---

## Step 14: Understanding the Flow

Here's what happens when someone uses your system:

1. User uploads a document through the web interface (port 3000)
2. Your backend (port 8000) receives it and parses it locally
3. Your backend sends the text to the workstation's embedding service (port 8002)
4. The workstation converts text to mathematical vectors using GPU
5. These vectors are stored in Qdrant (port 6333)
6. When someone asks a question, your system:
   - Sends the question to the embedding service for vector conversion
   - Searches Qdrant for similar vectors
   - Retrieves relevant document chunks
   - Sends the question + context to vLLM (port 8001) for answer generation
   - Returns the answer to the user

---

## Step 15: Fallback Mode

What happens if your workstation goes down? No worries! You can set `GPU_AVAILABLE=false` in your .env file, and your system will automatically use CPU-based models to continue working.

---

## Tips for Success

1. **Start Small**: Begin with a simple document and basic questions
2. **Monitor Resources**: Keep an eye on GPU and memory usage
3. **Backup Models**: Keep copies of your trained models
4. **Test Often**: Regular testing helps catch issues early
5. **Read Documentation**: The docs are your best friend!

---

## Common Issues and Solutions

**Issue**: Docker can't access GPU  
**Solution**: Make sure NVIDIA drivers and nvidia-container-toolkit are installed

**Issue**: Connection refused to workstation  
**Solution**: Check your Tailscale VPN or LAN connection

**Issue**: Slow performance  
**Solution**: Monitor GPU usage and optimize model sizes

---

## You Did It!

Congratulations! You've just installed a complete RAG system that can understand documents and answer questions using AI. This is a powerful system that separates development from computation, making it easy to develop and deploy AI applications.

Remember, this is just the beginning. You can now add more features, improve the UI, or even train your own models. The sky's the limit!

Happy coding!
