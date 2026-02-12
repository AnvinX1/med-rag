# Product Requirements Document (PRD)

## Project Title
Medical GenAI RAG & Fine-Tuned LLM System

## Author
Victor

## Version
v1.0

## Last Updated
2026-02-12

---

## 1. Overview

This project aims to design, build, and deploy a **Medical-domain Generative AI system** using **Retrieval-Augmented Generation (RAG)** combined with **fine-tuned transformer models**. The system will be developed using **agent-assisted development**, fully documented, open-sourced, and aligned with **GenAI Intern technical interview expectations**.

The system will allow users to query medical documents (research papers, guidelines, PDFs) and receive accurate, context-grounded responses using modern LLM pipelines.

---

## 2. Goals & Objectives

### Primary Goals
- Build a **production-style GenAI system** end-to-end
- Learn and reinforce **Python fundamentals** through real code
- Demonstrate hands-on experience with:
  - RAG
  - Fine-tuning (LoRA / QLoRA)
  - Quantization
  - Model orchestration
  - Deployment

### Secondary Goals
- Prepare for **technical interviews**
- Create a **strong open-source portfolio project**
- Practice working with **remote GPU servers**

---

## 3. Non-Goals

- Building a fully regulated clinical decision system
- Providing medical advice (strict disclaimer enforced)
- Training very large models (>13B)

---

## 4. Target Users

- Recruiters & interviewers
- GenAI engineers reviewing open-source work
- Developers exploring RAG systems
- The author (learning + revision)

---

## 5. Functional Requirements

### 5.1 Data Ingestion
- Load medical PDFs and text files
- Extract clean text
- Chunk text with overlap
- Store processed outputs

### 5.2 Embeddings & Vector Store
- Generate embeddings using Sentence Transformers
- Store embeddings in FAISS
- Support similarity search

### 5.3 Retrieval-Augmented Generation (RAG)
- Retrieve top-k relevant chunks
- Inject context into LLM prompts
- Ensure grounded responses

### 5.4 Fine-Tuning Pipeline
- Fine-tune a small transformer model (e.g., LLaMA / Mistral)
- Use LoRA / QLoRA
- Support quantization (4-bit / 8-bit)
- Log GPU usage and metrics

### 5.5 Inference Pipeline
- Load base model + adapters
- Tokenize input
- Generate responses efficiently

### 5.6 Orchestration Framework
- Central pipeline manager
- Modular execution (ingestion → retrieval → generation)
- Clear interfaces between components

### 5.7 API Layer
- FastAPI-based backend
- `/ask` endpoint
- JSON request/response

### 5.8 Documentation
- Architecture documentation
- Module-level explanations
- Learning notes
- Setup & usage guides

---

## 6. Non-Functional Requirements

- Code readability over cleverness
- Beginner-friendly Python
- GPU-efficient execution
- Deterministic, reproducible pipelines
- Open-source compatible licensing

---

## 7. System Architecture

```
Client
  ↓
FastAPI
  ↓
Orchestration Pipeline
  ├── Retriever (FAISS)
  ├── Prompt Builder
  └── Generator (LLM)
  ↓
Response
```

---

## 8. Tech Stack

### Languages
- Python 3.10+

### ML / GenAI
- PyTorch
- Transformers (HuggingFace)
- PEFT (LoRA / QLoRA)
- BitsAndBytes

### RAG
- LangChain (light usage)
- FAISS
- Sentence Transformers

### Backend
- FastAPI
- Uvicorn

### Infra
- Remote Linux Server
- NVIDIA L40S GPUs
- GitHub

---

## 9. Project Structure

```
medical-genai-rag/
│
├── data/
│   ├── raw/
│   ├── processed/
│
├── ingestion/
│   ├── loader.py
│   ├── chunker.py
│
├── embeddings/
│   ├── embedder.py
│   ├── vector_store.py
│
├── finetuning/
│   ├── lora_train.py
│
├── inference/
│   ├── model_loader.py
│
├── orchestration/
│   ├── pipeline.py
│
├── api/
│   ├── app.py
│
├── docs/
│   ├── architecture.md
│   ├── learning_notes.md
│
├── README.md
├── requirements.txt
└── prd.md
```

---

## 10. Development Phases

### Phase 1: Environment & Repo Setup
- Python venv
- Dependency installation
- GitHub repository

### Phase 2: Ingestion Pipeline
- PDF loading
- Text chunking
- Validation

### Phase 3: Embeddings & Retrieval
- Embedding generation
- FAISS index
- Similarity search

### Phase 4: Fine-Tuning
- Dataset preparation
- LoRA training
- Quantization

### Phase 5: Inference
- Adapter loading
- Prompt testing

### Phase 6: Orchestration
- Pipeline abstraction
- Error handling

### Phase 7: API Deployment
- FastAPI app
- Endpoint testing

### Phase 8: Documentation & Open Source
- README
- Diagrams
- Learning notes

---

## 11. Risks & Mitigations

| Risk | Mitigation |
|-----|-----------|
| Python skill gap | Inline comments + learning notes |
| Time constraints | Agent-assisted development |
| GPU failures | Small models + checkpoints |
| Over-complexity | Modular, incremental build |

---

## 12. Ethics & Compliance

- No real medical advice
- Clear medical disclaimer
- Research-only usage
- Data privacy respected

---

## 13. Success Metrics

- End-to-end pipeline runs successfully
- RAG answers are context-grounded
- Fine-tuned model improves outputs
- Clear documentation exists
- Interview-ready explanations

---

## 14. Future Enhancements

- Evaluation metrics (BLEU, ROUGE)
- Multi-document querying
- UI frontend (Tauri / Web)
- Model monitoring

---

## 15. Appendix

This PRD is designed to be both a **build guide** and a **learning contract**, ensuring fast delivery without sacrificing understanding.

