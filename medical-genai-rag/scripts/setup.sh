#!/bin/bash
# ============================================
# setup.sh - Environment Setup Script
# Medical GenAI RAG System
# ============================================

set -e  # Exit on error

echo "============================================"
echo "  Medical GenAI RAG System - Setup"
echo "============================================"

PROJECT_DIR="$HOME/medical-genai-rag"
cd "$PROJECT_DIR"

# 1. Create virtual environment
echo ""
echo "[1/4] Creating Python virtual environment..."
if [ ! -d "venv" ]; then
    python3 -m venv venv
    echo "  ✓ Virtual environment created"
else
    echo "  ✓ Virtual environment already exists"
fi

# 2. Activate and upgrade pip
echo ""
echo "[2/4] Activating environment and upgrading pip..."
source venv/bin/activate
pip install --upgrade pip setuptools wheel 2>&1 | tail -1

# 3. Install dependencies
echo ""
echo "[3/4] Installing dependencies..."
pip install -r requirements.txt 2>&1 | tail -5
echo "  ✓ Dependencies installed"

# 4. Verify installation
echo ""
echo "[4/4] Verifying installation..."
python3 -c "
import torch
import transformers
import peft
import faiss
import sentence_transformers
from fastapi import FastAPI

print(f'  PyTorch: {torch.__version__}')
print(f'  CUDA available: {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'  GPU: {torch.cuda.get_device_name(0)}')
    print(f'  GPU Memory: {torch.cuda.get_device_properties(0).total_mem / 1e9:.1f} GB')
print(f'  Transformers: {transformers.__version__}')
print(f'  PEFT: {peft.__version__}')
print(f'  FAISS: OK')
print(f'  Sentence Transformers: {sentence_transformers.__version__}')
print(f'  FastAPI: OK')
"

echo ""
echo "============================================"
echo "  Setup complete!"
echo "  Activate with: source venv/bin/activate"
echo "============================================"
