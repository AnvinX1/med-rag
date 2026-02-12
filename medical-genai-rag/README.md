# Medical GenAI RAG System

> A production-style Retrieval-Augmented Generation system for medical queries, built with PyTorch, HuggingFace Transformers, FAISS, and FastAPI.

⚠️ **DISCLAIMER**: This system is for **educational and research purposes only**. It does NOT provide medical advice. Always consult a qualified healthcare professional.

---

## 🏗️ Architecture

```
Client (API Request)
      ↓
  FastAPI Server
      ↓
Orchestration Pipeline
  ├── Document Ingestion (PDF/TXT → chunks)
  ├── Embedding (Sentence Transformers → FAISS)
  ├── Retriever (FAISS similarity search)
  ├── Prompt Builder (context injection)
  └── Generator (Fine-tuned LLM via LoRA/QLoRA)
      ↓
  JSON Response
```

## 📁 Project Structure

```
medical-genai-rag/
├── data/
│   ├── raw/              # Input medical documents (PDFs, TXT)
│   └── processed/        # Chunked data, FAISS index, training data
├── ingestion/
│   ├── loader.py          # Document loading (PDF, TXT, MD)
│   └── chunker.py         # Text chunking with overlap
├── embeddings/
│   ├── embedder.py        # Sentence Transformer embeddings
│   └── vector_store.py    # FAISS vector storage & search
├── finetuning/
│   └── lora_train.py      # LoRA/QLoRA fine-tuning pipeline
├── inference/
│   └── model_loader.py    # Model loading & text generation
├── orchestration/
│   └── pipeline.py        # Central RAG pipeline orchestrator
├── api/
│   └── app.py             # FastAPI REST API
├── scripts/
│   ├── setup.sh           # Environment setup script
│   └── run_training.sh    # Fine-tuning launch script
├── docs/
│   ├── architecture.md    # Detailed architecture docs
│   └── learning_notes.md  # Learning notes & explanations
├── requirements.txt
└── README.md
```

## 🚀 Quick Start

### 1. Setup Environment

```bash
# Clone and setup
cd ~/medical-genai-rag
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### 2. Add Medical Documents

Place PDF/TXT files in `data/raw/`:
```bash
cp your_medical_docs.pdf data/raw/
```

### 3. Build Index

```bash
python -c "
from orchestration.pipeline import RAGPipeline
pipeline = RAGPipeline()
pipeline.build_index()
"
```

### 4. Run Fine-Tuning (GPU required)

```bash
python finetuning/lora_train.py --base-model mistralai/Mistral-7B-Instruct-v0.2
```

### 5. Start API Server

```bash
python -m api.app
# API available at http://localhost:8000
# Docs at http://localhost:8000/docs
```

### 6. Query the System

```bash
curl -X POST http://localhost:8000/ask \
  -H "Content-Type: application/json" \
  -d '{"question": "What are the symptoms of diabetes?"}'
```

## 🧠 Tech Stack

| Component | Technology |
|-----------|-----------|
| Language | Python 3.10+ |
| ML Framework | PyTorch |
| LLM | HuggingFace Transformers |
| Fine-tuning | PEFT (LoRA/QLoRA) + TRL |
| Quantization | BitsAndBytes (4-bit NF4) |
| Embeddings | Sentence Transformers |
| Vector Store | FAISS |
| API | FastAPI + Uvicorn |
| GPU | NVIDIA L40S |

## 🔧 Key Concepts

### RAG (Retrieval-Augmented Generation)
Instead of relying solely on the LLM's training data, RAG retrieves relevant documents and injects them as context into the prompt. This grounds the response in actual data and reduces hallucination.

### LoRA (Low-Rank Adaptation)
Instead of fine-tuning all billions of parameters, LoRA adds small trainable adapter matrices to specific layers. This reduces memory usage by 10-100x while maintaining most of the performance.

### QLoRA (Quantized LoRA)
Combines 4-bit quantization of the base model with LoRA adapters trained in float16. This enables fine-tuning 7B+ parameter models on a single GPU.

## 📊 API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | API info |
| GET | `/health` | Health check |
| POST | `/ask` | Ask a medical question (RAG) |
| POST | `/index` | Build/rebuild FAISS index |
| POST | `/retrieve` | Retrieve chunks (debug) |

## 📝 License

MIT License - For educational and research purposes.

## 👤 Author

Victor - GenAI Intern Project
