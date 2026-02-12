#!/usr/bin/env python3
"""
test_pipeline.py - Test the full RAG pipeline
"""
import sys
sys.path.insert(0, ".")

print("=" * 60)
print("TESTING MEDICAL GENAI RAG PIPELINE")
print("=" * 60)

# === Step 1: Ingestion ===
print("\n[1/4] Testing Ingestion...")
from ingestion.loader import DocumentLoader
from ingestion.chunker import TextChunker

loader = DocumentLoader("data/raw")
docs = loader.load_all()
print(f"  Loaded {len(docs)} documents")
for doc in docs:
    print(f"    [{doc['type']}] {doc['source']} - {len(doc['text'])} chars")

chunker = TextChunker(chunk_size=512, chunk_overlap=50)
chunks = chunker.chunk_documents(docs)
print(f"  Created {len(chunks)} chunks")

# === Step 2: Embeddings ===
print("\n[2/4] Testing Embeddings...")
from embeddings.embedder import TextEmbedder
from embeddings.vector_store import VectorStore

embedder = TextEmbedder()
texts = [c["text"] for c in chunks]
embeddings = embedder.embed(texts)
print(f"  Generated embeddings: shape={embeddings.shape}")

# === Step 3: Vector Store ===
print("\n[3/4] Testing Vector Store...")
store = VectorStore(dimension=embedder.embedding_dim)
metadata = [
    {
        "text": c["text"],
        "source": c["source"],
        "chunk_id": c["chunk_id"],
        "chunk_index": c["chunk_index"],
    }
    for c in chunks
]
store.add(embeddings, metadata)
store.save("data/processed/faiss_index")
print(f"  Index built with {store.size} vectors")

# === Step 4: Retrieval Test ===
print("\n[4/4] Testing Retrieval...")
queries = [
    "What are the symptoms of diabetes?",
    "How do statins work?",
    "What is heart failure?",
    "What is the mechanism of action of metformin?",
]

for q in queries:
    query_emb = embedder.embed_query(q)
    results = store.search(query_emb, top_k=3)
    print(f"\n  Query: \"{q}\"")
    for r in results:
        text_preview = r["metadata"]["text"][:80].replace("\n", " ")
        print(f"    [{r['rank']}] score={r['score']:.4f}: {text_preview}...")

print("\n" + "=" * 60)
print("ALL TESTS PASSED!")
print("=" * 60)
