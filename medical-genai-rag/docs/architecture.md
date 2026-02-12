# Architecture Documentation

## System Overview

The Medical GenAI RAG System is a modular pipeline that combines document retrieval with language model generation to answer medical questions grounded in source documents.

## Component Architecture

### 1. Ingestion Layer (`ingestion/`)

**Purpose**: Convert raw documents into processable text chunks.

```
PDF/TXT/MD Files → DocumentLoader → Raw Text → TextChunker → Overlapping Chunks
```

- **DocumentLoader**: Handles multi-format document loading using PyMuPDF for PDFs
- **TextChunker**: Splits text with configurable chunk size and overlap
  - Smart boundary detection (paragraph → sentence → word)
  - Preserves metadata (source file, chunk index)

### 2. Embedding Layer (`embeddings/`)

**Purpose**: Convert text into dense vector representations for similarity search.

```
Text Chunks → SentenceTransformer → Normalized Vectors → FAISS Index
```

- **TextEmbedder**: Uses `all-MiniLM-L6-v2` (384-dim) for fast, quality embeddings
- **VectorStore**: FAISS IndexFlatIP for cosine similarity search
  - Supports save/load for persistence
  - Parallel metadata storage

### 3. Fine-Tuning Layer (`finetuning/`)

**Purpose**: Adapt a pre-trained LLM to the medical domain.

```
Medical Q&A Data → QLoRA Setup → SFTTrainer → LoRA Adapters
```

- **Quantization**: 4-bit NF4 via BitsAndBytes
- **LoRA Config**: r=16, alpha=32, targeting all attention + MLP layers
- **Training**: SFTTrainer with cosine LR schedule, gradient checkpointing

### 4. Inference Layer (`inference/`)

**Purpose**: Load and run the fine-tuned model for text generation.

```
User Query → Tokenization → Model (Base + Adapter) → Token Generation → Response
```

- Supports base model only or base + LoRA adapter
- Configurable generation parameters (temperature, top-p, top-k)

### 5. Orchestration Layer (`orchestration/`)

**Purpose**: Wire all components together into a coherent pipeline.

```
Query → Retrieve(FAISS) → BuildPrompt(Context+Question) → Generate(LLM) → Response
```

- Lazy loading of components (only load what's needed)
- Configurable via `PipelineConfig` dataclass

### 6. API Layer (`api/`)

**Purpose**: Expose the pipeline as a REST API.

- FastAPI with Pydantic validation
- Lifespan management for model loading
- CORS support for frontend integration

## Data Flow

```
                    ┌──────────────┐
                    │  Raw Docs    │
                    │  (PDF/TXT)   │
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │  Ingestion   │
                    │  Load+Chunk  │
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │  Embedding   │
                    │  SBERT→FAISS │
                    └──────┬───────┘
                           │
         ┌─────────────────┤
         │                 │
  ┌──────▼───────┐  ┌──────▼───────┐
  │  FAISS Index │  │  Fine-Tune   │
  │  (Retrieval) │  │  (LoRA/QLoRA)│
  └──────┬───────┘  └──────┬───────┘
         │                 │
         └────────┬────────┘
                  │
           ┌──────▼───────┐
           │ Orchestration │
           │   Pipeline    │
           └──────┬───────┘
                  │
           ┌──────▼───────┐
           │   FastAPI     │
           │   /ask        │
           └──────────────┘
```

## GPU Memory Estimates

| Component | Memory |
|-----------|--------|
| Mistral-7B (4-bit) | ~5 GB |
| LoRA Adapters | ~0.1 GB |
| FAISS Index (10k docs) | ~0.1 GB |
| Embedding Model | ~0.3 GB |
| Training (batch=4) | ~12 GB |
| **Total (inference)** | **~5.5 GB** |
| **Total (training)** | **~17 GB** |
