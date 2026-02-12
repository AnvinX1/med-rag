#!/bin/bash
# ============================================
# run_pipeline.sh - Build Index & Test Pipeline
# Medical GenAI RAG System
# ============================================

set -e

PROJECT_DIR="$HOME/medical-genai-rag"
cd "$PROJECT_DIR"
source venv/bin/activate

echo "============================================"
echo "  Medical GenAI RAG - Pipeline Test"
echo "============================================"

# Step 1: Build FAISS index
echo ""
echo "[1/3] Building FAISS index from documents..."
python3 -c "
import sys
sys.path.insert(0, '.')
from orchestration.pipeline import RAGPipeline, PipelineConfig

config = PipelineConfig()
pipeline = RAGPipeline(config)
num = pipeline.build_index(force=True)
print(f'  Index built with {num} chunks')
"

# Step 2: Test retrieval
echo ""
echo "[2/3] Testing retrieval..."
python3 -c "
import sys
sys.path.insert(0, '.')
from orchestration.pipeline import RAGPipeline, PipelineConfig

pipeline = RAGPipeline(PipelineConfig())
pipeline.build_index()

queries = [
    'What are the symptoms of diabetes?',
    'How do statins work?',
    'What is heart failure?',
]

for q in queries:
    results = pipeline.retrieve(q, top_k=3)
    print(f'\n  Query: \"{q}\"')
    for r in results:
        print(f'    [{r[\"rank\"]}] score={r[\"score\"]:.4f}: {r[\"metadata\"][\"text\"][:60]}...')
"

# Step 3: Start API
echo ""
echo "[3/3] Starting FastAPI server..."
echo "  Access at: http://0.0.0.0:8000"
echo "  Docs at:   http://0.0.0.0:8000/docs"
echo ""
python3 -m uvicorn api.app:app --host 0.0.0.0 --port 8000
