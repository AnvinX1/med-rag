# Learning Notes

## Python Fundamentals Used in This Project

### 1. Data Classes (`@dataclass`)
Used in `FineTuneConfig` and `PipelineConfig` to cleanly define configuration objects.
```python
@dataclass
class FineTuneConfig:
    base_model: str = "mistralai/Mistral-7B-Instruct-v0.2"
    lora_r: int = 16
```
**Why?** Reduces boilerplate compared to writing `__init__` manually.

### 2. Type Hints
Every function uses type annotations for clarity:
```python
def embed(self, texts: List[str], batch_size: int = 64) -> np.ndarray:
```
**Why?** Makes code self-documenting and catches bugs early with tools like mypy.

### 3. Properties (`@property`)
Used for lazy loading in the pipeline:
```python
@property
def embedder(self):
    if self._embedder is None:
        self._embedder = TextEmbedder()
    return self._embedder
```
**Why?** Components are only loaded when first accessed, saving memory.

### 4. Context Managers
Used in document loading:
```python
with open(file_path, "r") as f:
    text = f.read()
```
**Why?** Ensures files are properly closed even if an error occurs.

### 5. List Comprehensions
Used throughout for data transformation:
```python
texts = [c["text"] for c in chunks]
```

---

## GenAI / ML Concepts

### RAG (Retrieval-Augmented Generation)
**Problem:** LLMs can hallucinate or have outdated information.
**Solution:** Retrieve relevant documents and inject them into the prompt.
**Flow:** Query → Embed → Search FAISS → Get top-k chunks → Inject into prompt → Generate

### LoRA (Low-Rank Adaptation)
**Problem:** Fine-tuning all parameters of a 7B model requires massive GPU memory.
**Solution:** Add small trainable matrices (rank r) to specific layers.
**Math:** W' = W + BA, where B is (d×r) and A is (r×d), with r << d
**Benefit:** Only train ~0.1% of parameters, save ~10x memory.

### QLoRA
**Addition to LoRA:** Quantize base model to 4-bit (NF4 format).
**Benefit:** Further reduces memory, enabling 7B model fine-tuning on 16GB GPU.

### FAISS (Facebook AI Similarity Search)
**What:** Library for efficient similarity search over dense vectors.
**How:** We use IndexFlatIP (Inner Product) with L2-normalized vectors = cosine similarity.
**Speed:** Exact search for small datasets; can use IVF/HNSW for millions of vectors.

### Sentence Transformers
**What:** Models that produce fixed-size embeddings for sentences/paragraphs.
**Model:** `all-MiniLM-L6-v2` - 384 dimensions, fast, good quality.
**Why not raw LLM embeddings?** Sentence Transformers are specifically trained for similarity.

### Quantization
**What:** Reducing numerical precision of model weights.
**Types:**
- FP32 (4 bytes) → FP16 (2 bytes) → INT8 (1 byte) → INT4 (0.5 bytes)
- NF4 (Normal Float 4): Optimal for normally distributed neural network weights
**Tradeoff:** Slight quality loss for massive memory savings.

---

## Interview-Ready Explanations

### "How does your RAG system work?"
"The system has three main stages: First, medical documents are loaded, chunked, and embedded using a Sentence Transformer model, then stored in a FAISS index. When a user asks a question, the query is embedded and we search the FAISS index for the top-k most similar chunks. These chunks are injected as context into a prompt template, which is then fed to a fine-tuned LLM that generates a grounded response."

### "Why did you use LoRA instead of full fine-tuning?"
"Full fine-tuning of a 7B model would require 28+ GB of GPU memory just for the weights, plus optimizer states. LoRA adds small trainable matrices (rank 16) to specific layers, reducing trainable parameters to about 0.1% of the total. With QLoRA, we quantize the base model to 4-bit, so the entire training fits in about 12 GB."

### "How do you ensure the responses are grounded?"
"Three ways: First, RAG retrieves actual source text, so the model has real context. Second, the prompt explicitly instructs the model to base its answer on the provided context. Third, we return the source documents with every response so users can verify."
