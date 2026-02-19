# Technical Terms and Definitions

This document organizes technical terms from the RAG and LLM ecosystem in a structured format for easy reference.

| Term | Definition | Description | Examples / Resources |
|------|------------|-------------|----------|
| **Adapter** | Small trainable module attached to frozen base model — output of LoRA training. Merged back into model after training | A small, trainable component that can be attached to a pre-trained model to adapt it for specific tasks without retraining the entire model | Saved as separate file, merged via Unsloth |
| **Argilla** | Self-hosted LLM dataset curation UI — purpose-built for preference labeling and DPO data collection | A platform for curating datasets for LLM training, particularly for preference-based training methods | argilla.io |
| **Axolotl** | Training framework for LLM fine-tuning — supports LoRA, QLoRA, and full fine-tuning methods | HuggingFace-compatible library for efficient LLM training | github.com/unslothai/axolotl |
| **BERT** | Bidirectional Encoder Representations from Transformers | Google 2018 — reads text bidirectionally, produces contextual representations. Foundation of all modern embedding models | BioBERT, PubMedBERT, ClinicalBERT |
| **BM25** | Best Match 25 | Standard keyword retrieval algorithm. Complements dense retrieval in hybrid search | Qdrant hybrid, LlamaIndex |
| **CAI** | Constitutional AI | Model critiques its own outputs against explicit principles — Anthropic's alignment approach. Relevant for encoding clinical safety rules | Anthropic research papers |
| **Chunk Size** | How large each piece is — typically 256-1024 tokens. Too large loses precision, too small loses context | The size of text segments used for embedding and retrieval in RAG systems | LlamaIndex, Chonkie |
| **Chunking** | Splitting documents into smaller pieces for embedding and retrieval. Strategy directly impacts retrieval quality | The process of dividing large documents into smaller, manageable segments for processing | LlamaIndex node parsers, LangChain splitters |
| **Continuous Batching** | Processing multiple requests simultaneously mid-stream — GPU never idle | A technique for maximizing GPU utilization by processing multiple inference requests concurrently | vLLM core feature |
| **Context Window** | Maximum tokens a model can process at once — determines chunk size ceiling and prompt length limits | The maximum number of tokens that can be processed in a single model inference call | Qwen3-Coder: 32768 tokens |
| **Cosine Similarity** | Measures angle between two vectors — most common similarity metric. 1 = identical, 0 = unrelated, -1 = opposite | A measure of similarity between two vectors, commonly used in vector databases | Default in most vector DBs |
| **Dense Retrieval** | Pure vector similarity search — semantic matching | Retrieval method that uses vector similarity to find relevant documents | Qdrant, pgvector |
| **Dimensionality** | Size of output embedding vector — 768, 1024, 4096. Higher = more expressive, more storage, slower | The number of dimensions in an embedding vector | BGE-M3: 1024, PubMedBERT: 768 |
| **Distilabel** | Synthetic data generation pipeline framework — structured LLM-generated dataset creation | A framework for generating synthetic datasets using LLMs | github.com/argilla-io/distilabel |
| **DPO** | Direct Preference Optimization | Chosen vs rejected response pairs, no reward model needed. Simpler alternative to RLHF | TRL DPOTrainer |
| **Embedding** | Fixed-size vector of numbers representing semantic meaning of text. Similar meaning = similar vectors = close in vector space | A numerical representation of text that captures semantic relationships | BGE-M3, MedCPT, E5 |
| **Embedding Model** | Neural network converting text to embeddings — smaller, faster than LLMs, purpose-built for similarity | Models specifically designed to convert text into numerical vectors | BGE-M3, MedCPT, BioLORD |
| **Fine-tuning** | Further training a pre-trained model on your specific data to change its behavior permanently | The process of adapting a pre-trained model to a specific task or domain | Unsloth, TRL, Axolotl |
| **FP8 / FP16 / INT4** | Float8 / Float16 / Integer4 | Numerical precision formats for model weights. Lower precision = smaller, faster, slight quality tradeoff | Qwen3-Coder-30B-FP8 |
| **GGUF** | GPT-Generated Unified Format | Model file format used by llama.cpp — quantized, single file, CPU/GPU flexible | llama.cpp, Ollama |
| **HuggingFace Hub** | Central repository for models, datasets, spaces — primary source for open-source models | A platform for sharing and accessing machine learning models and datasets | huggingface.co |
| **Hybrid Retrieval** | Combines dense (semantic) + sparse (keyword) search — best of both. Current best practice for RAG | A retrieval approach that combines vector similarity search with keyword-based search | Qdrant, LlamaIndex |
| **HyDE** | Hypothetical Document Embedding | LLM generates hypothetical answer, embeds it, retrieves similar chunks instead of using raw query | LlamaIndex HyDEQueryTransform |
| **Inference** | Running a model to generate output — distinct from training | The process of using a trained model to make predictions or generate text | vLLM, Ollama, llama.cpp |
| **Knowledge Distillation** | Training smaller model to mimic larger model outputs — transfers capability without transferring size | A technique for compressing large models into smaller, more efficient versions | — |
| **KTO** | Kahneman-Tversky Optimization | Preference training on single labeled responses — good or bad — no pairs needed. Easier data collection than DPO | TRL KTOTrainer |
| **KV Cache** | Key-Value Cache | Stores intermediate attention computations to avoid recalculation — critical for inference speed | Managed by PagedAttention in vLLM |
| **Label Studio** | Self-hosted annotation UI — broader task support, flexible, more complex than Argilla | A platform for data annotation and labeling | labelstud.io |
| **LangChain** | RAG/agent orchestration framework — broader tooling, more flexible, more boilerplate than LlamaIndex | A framework for building applications with LLMs | langchain.com |
| **llama.cpp** | C++ inference engine for LLMs — runs models on CPU/GPU — uses GGUF format | Efficient, portable LLM inference engine with minimal dependencies | github.com/ggerganov/llama.cpp |
| **LlamaIndex** | RAG orchestration framework — document loading, chunking, embedding, retrieval, LLM calls. RAG-first design | A framework specifically designed for Retrieval Augmented Generation applications | llamaindex.ai |
| **LLM** | Large Language Model | Neural network trained on massive text to understand and generate language | Qwen3-Coder, Claude, GPT-4 |
| **LoRA** | Low-Rank Adaptation | Attaches small trainable adapter layers to frozen base model — trains fraction of parameters, fraction of VRAM | Unsloth, HuggingFace PEFT |
| **MMR** | Maximal Marginal Relevance | Retrieval strategy balancing relevance and diversity — avoids returning redundant chunks | LlamaIndex retriever config |
| **MoE** | Mixture of Experts | Architecture where model activates only a subset of specialized sub-networks per token — efficient at scale | Qwen3-Coder (30B total, 3B active) |
| **MTEB** | Massive Text Embedding Benchmark | Standard leaderboard for comparing embedding models across retrieval and other tasks | huggingface.co/spaces/mteb/leaderboard |
| **Multi-query Retrieval** | LLM generates multiple query versions, retrieves for each, merges results — improves recall | A technique that generates multiple query variations to improve retrieval results | LlamaIndex MultiStepQueryEngine |
| **NIC** | Network Interface Card | Physical hardware managing network connectivity | eth0, eth1 — your 2x Intel X710 10GbE |
| **Open WebUI** | Web interface for LLMs — provides chat UI, model management, and API access | Browser-based interface for interacting with LLMs and managing models | github.com/open-webui/open-webui |
| **ORPO** | Odds Ratio Preference Optimization | Combines SFT and DPO into single training pass — faster, less data needed | TRL ORPOTrainer |
| **Overlap** | Shared content between adjacent chunks — prevents context loss at boundaries | The amount of shared text between consecutive document chunks | LlamaIndex |
| **PagedAttention** | vLLM memory management — manages KV cache like OS virtual memory, eliminates waste | Memory management technique that optimizes attention computation caching | vLLM core feature |
| **PEFT** | Parameter Efficient Fine-Tuning | Umbrella term for methods training small parameter subsets — LoRA and QLoRA are PEFT methods | HuggingFace PEFT library |
| **pgvector** | PostgreSQL extension adding vector storage and similarity search to existing Postgres | A PostgreSQL extension that adds vector database capabilities | github.com/pgvector/pgvector |
| **Pooling** | Collapsing per-token vectors into single sentence vector. Mean pooling most common | A technique for combining token-level embeddings into a single sentence-level embedding | Mean, CLS, Max |
| **PPO** | Proximal Policy Optimization | Reinforcement learning algorithm inside RLHF training loop — handled by TRL | TRL PPOTrainer |
| **QDrant** | Purpose-built vector database — self-hostable, fast, native hybrid search, multi-collection | A vector database optimized for similarity search | qdrant.tech |
| **QLoRA** | Quantized LoRA | LoRA on quantized base model — even less VRAM, slight quality tradeoff vs LoRA | Unsloth |
| **Quantization** | Compressing model weights to lower precision — reduces VRAM and increases speed at slight quality cost | A technique for reducing model size and improving inference speed | FP8, QLoRA, GGUF |
| **RAG** | Retrieval Augmented Generation | Retrieve relevant data at query time, inject into prompt — model reasons over it without retraining | LlamaIndex, LangChain |
| **Re-ranking** | Second-pass model scores retrieved chunks by relevance, reorders before sending to LLM | A process that re-ranks retrieved results for better relevance | BGE-reranker, Cohere Rerank, FlashRank |
| **Reward Model** | Separate model trained to predict human preference scores — proxy for human judgment in RLHF | A model used to evaluate the quality of outputs in RLHF training | Used in full RLHF pipeline |
| **RLAIF** | Reinforcement Learning from AI Feedback | Same as RLHF but AI generates preference labels instead of human — scales data collection | Distilabel |
| **RLHF** | Reinforcement Learning from Human Feedback | Full preference alignment — human ranks outputs, reward model trained, main model optimized against it | Used to train ChatGPT, Claude |
| **Safetensors** | HuggingFace model weight format — safe, fast loading, sharded for large models | A format for storing model weights that's safe and efficient | All HuggingFace model downloads |
| **SFT** | Supervised Fine-Tuning | Train model directly on correct input/output pairs. Foundation step before preference alignment | TRL SFTTrainer |
| **Similarity Search** | Finding vectors closest to query vector in vector space — core retrieval operation in RAG | The process of finding similar vectors in a vector database | Qdrant, pgvector |
| **Sparse Retrieval** | Keyword-based search — exact term matching. BM25 is the standard algorithm | A retrieval method that uses keyword matching | Elasticsearch, Qdrant |
| **SWE-Bench** | Software Engineering Benchmark | Measures LLM ability to solve real GitHub issues — gold standard for coding model evaluation | Qwen3-Coder: 69.6% |
| **Synthetic Data** | Training examples generated by an LLM rather than written by humans. Requires human review before use | Data created by LLMs for training purposes | Distilabel |
| **Tailscale** | VPN mesh network — assigns stable IPs (100.x.x.x) across devices regardless of location | A VPN service that creates secure networks between devices | tailscale.com |
| **Tensor Parallelism** | Splitting model across multiple GPUs — vLLM handles natively | A technique for distributing model computation across multiple GPUs | --tensor-parallel-size 3 |
| **Throughput** | Tokens generated per second across concurrent requests — key inference performance metric | A measure of how many tokens a system can process per second | vLLM continuous batching |
| **Tokenization** | Process of converting text to tokens — numbers the model actually processes | The process of breaking text into tokens that can be processed by a model | HuggingFace tokenizers |
| **Tokenizer** | Splits text into subword tokens before model processing. Must match model at ingestion and query time | A component that converts text into tokens for model processing | HuggingFace tokenizers |
| **Transformer** | Neural network architecture using attention mechanism — foundation of all modern LLMs and embedding models | The foundational architecture for modern NLP models | All LLMs, BERT variants |
| **TRL** | Transformer Reinforcement Learning | HuggingFace library implementing all fine-tuning methods — SFT, DPO, PPO, KTO, ORPO | github.com/huggingface/trl |
| **Unsloth** | Training optimization library — faster, less VRAM, wraps HuggingFace for LoRA/QLoRA fine-tuning | A library that optimizes the fine-tuning process | github.com/unslothai/unsloth |
| **Vector** | List of numbers encoding meaning. Similar meaning = similar numbers = close in vector space | A numerical representation of text or other data | — |
| **Vector Database** | Storage optimized for similarity search on vectors | Databases specifically designed for storing and searching vector data | Qdrant, pgvector, Weaviate, Chroma |
| **venv** | Virtual Environment | Isolated Python environment — packages installed here don't affect system or other venvs | uv venv ~/venvs/vllm |
| **vLLM** | High-performance inference engine — PagedAttention, continuous batching, tensor parallelism, OpenAI-compatible API | A fast inference engine for LLMs | github.com/vllm-project/vllm |
| **W&B** | Weights & Biases | Experiment tracking — logs training metrics, loss curves, model comparisons via browser dashboard | wandb.ai |