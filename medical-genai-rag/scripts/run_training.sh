#!/bin/bash
# ============================================
# run_training.sh - Fine-Tuning Launch Script
# Medical GenAI RAG System
# ============================================

set -e

echo "============================================"
echo "  Medical GenAI RAG - Fine-Tuning"
echo "============================================"

PROJECT_DIR="$HOME/medical-genai-rag"
cd "$PROJECT_DIR"

# Activate virtual environment
source venv/bin/activate

# Check GPU
echo ""
echo "GPU Status:"
nvidia-smi --query-gpu=name,memory.total,memory.free --format=csv,noheader 2>/dev/null || echo "  No GPU detected!"

# Configuration
BASE_MODEL="${BASE_MODEL:-mistralai/Mistral-7B-Instruct-v0.2}"
EPOCHS="${EPOCHS:-3}"
BATCH_SIZE="${BATCH_SIZE:-4}"
LR="${LR:-2e-4}"
LORA_R="${LORA_R:-16}"
OUTPUT_DIR="${OUTPUT_DIR:-./finetuning/outputs}"

echo ""
echo "Training Configuration:"
echo "  Base Model: $BASE_MODEL"
echo "  Epochs: $EPOCHS"
echo "  Batch Size: $BATCH_SIZE"
echo "  Learning Rate: $LR"
echo "  LoRA Rank: $LORA_R"
echo "  Output: $OUTPUT_DIR"

# Step 1: Create training dataset
echo ""
echo "[1/2] Creating training dataset..."
python3 finetuning/lora_train.py --create-dataset

# Step 2: Run training
echo ""
echo "[2/2] Starting fine-tuning..."
python3 finetuning/lora_train.py \
    --base-model "$BASE_MODEL" \
    --epochs "$EPOCHS" \
    --batch-size "$BATCH_SIZE" \
    --lr "$LR" \
    --lora-r "$LORA_R" \
    --output-dir "$OUTPUT_DIR"

echo ""
echo "============================================"
echo "  Fine-tuning complete!"
echo "  Adapter saved to: $OUTPUT_DIR/final_adapter"
echo "============================================"
