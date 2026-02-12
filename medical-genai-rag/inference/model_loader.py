"""
inference/model_loader.py
--------------------------
Loads fine-tuned LLM (base + LoRA adapters) for inference.

Key Concepts:
- Loading quantized models
- Merging LoRA adapters with base model
- Tokenization and generation
- Inference optimization
"""

import logging
import torch
from typing import Optional, Dict, Any

from transformers import (
    AutoModelForCausalLM,
    AutoTokenizer,
    BitsAndBytesConfig,
    GenerationConfig,
)
from peft import PeftModel

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class ModelLoader:
    """
    Loads and manages the fine-tuned LLM for inference.
    
    Supports:
    - Loading base model + LoRA adapter
    - Loading quantized models (4-bit/8-bit)
    - Text generation with configurable parameters
    
    Usage:
        loader = ModelLoader(
            base_model="mistralai/Mistral-7B-Instruct-v0.2",
            adapter_path="finetuning/outputs/final_adapter"
        )
        response = loader.generate("What is diabetes?")
    """
    
    def __init__(
        self,
        base_model: str = "mistralai/Mistral-7B-Instruct-v0.2",
        adapter_path: Optional[str] = None,
        load_in_4bit: bool = True,
        device: Optional[str] = None,
    ):
        """
        Args:
            base_model: HuggingFace model ID for the base model
            adapter_path: Path to LoRA adapter (None = use base model only)
            load_in_4bit: Whether to load in 4-bit quantization
            device: Device to load model on
        """
        self.base_model_name = base_model
        self.adapter_path = adapter_path
        self.load_in_4bit = load_in_4bit
        self.device = device or ("cuda" if torch.cuda.is_available() else "cpu")
        
        self.model = None
        self.tokenizer = None
        self._loaded = False
    
    def load(self):
        """Load the model and tokenizer."""
        if self._loaded:
            logger.info("Model already loaded, skipping...")
            return
        
        logger.info(f"Loading model: {self.base_model_name}")
        logger.info(f"Adapter: {self.adapter_path or 'None (base model only)'}")
        logger.info(f"4-bit quantization: {self.load_in_4bit}")
        
        # Configure quantization
        bnb_config = None
        if self.load_in_4bit and self.device == "cuda":
            bnb_config = BitsAndBytesConfig(
                load_in_4bit=True,
                bnb_4bit_quant_type="nf4",
                bnb_4bit_compute_dtype=torch.bfloat16,
                bnb_4bit_use_double_quant=True,
            )
        
        # Load tokenizer
        self.tokenizer = AutoTokenizer.from_pretrained(
            self.base_model_name,
            trust_remote_code=True,
        )
        self.tokenizer.pad_token = self.tokenizer.eos_token
        
        # Load base model
        model_kwargs = {
            "device_map": "auto",
            "trust_remote_code": True,
        }
        if bnb_config:
            model_kwargs["quantization_config"] = bnb_config
        
        self.model = AutoModelForCausalLM.from_pretrained(
            self.base_model_name,
            **model_kwargs,
        )
        
        # Load LoRA adapter if provided
        if self.adapter_path:
            logger.info(f"Loading LoRA adapter from: {self.adapter_path}")
            self.model = PeftModel.from_pretrained(
                self.model,
                self.adapter_path,
            )
            logger.info("LoRA adapter loaded successfully!")
        
        self.model.eval()
        self._loaded = True
        
        # Log model info
        total_params = sum(p.numel() for p in self.model.parameters())
        logger.info(f"Model loaded. Total parameters: {total_params:,}")
        if torch.cuda.is_available():
            mem = torch.cuda.memory_allocated() / 1e9
            logger.info(f"GPU memory used: {mem:.2f} GB")
    
    def generate(
        self,
        prompt: str,
        max_new_tokens: int = 512,
        temperature: float = 0.7,
        top_p: float = 0.9,
        top_k: int = 50,
        repetition_penalty: float = 1.1,
        do_sample: bool = True,
    ) -> str:
        """
        Generate text from a prompt.
        
        Args:
            prompt: Input text/prompt
            max_new_tokens: Maximum tokens to generate
            temperature: Sampling temperature (higher = more creative)
            top_p: Nucleus sampling parameter
            top_k: Top-k sampling parameter
            repetition_penalty: Penalty for repeating tokens
            do_sample: Use sampling (vs greedy decoding)
            
        Returns:
            Generated text string
        """
        if not self._loaded:
            self.load()
        
        # Tokenize input
        inputs = self.tokenizer(
            prompt,
            return_tensors="pt",
            padding=True,
            truncation=True,
            max_length=2048,
        ).to(self.model.device)
        
        # Generation config
        gen_config = GenerationConfig(
            max_new_tokens=max_new_tokens,
            temperature=temperature,
            top_p=top_p,
            top_k=top_k,
            repetition_penalty=repetition_penalty,
            do_sample=do_sample,
            pad_token_id=self.tokenizer.eos_token_id,
        )
        
        # Generate
        with torch.no_grad():
            outputs = self.model.generate(
                **inputs,
                generation_config=gen_config,
            )
        
        # Decode only the new tokens
        new_tokens = outputs[0][inputs["input_ids"].shape[-1]:]
        response = self.tokenizer.decode(new_tokens, skip_special_tokens=True)
        
        return response.strip()
    
    def format_medical_prompt(
        self,
        question: str,
        context: str = "",
    ) -> str:
        """
        Format a medical query with optional RAG context.
        
        Args:
            question: The user's medical question
            context: Retrieved context from RAG (optional)
            
        Returns:
            Formatted prompt string
        """
        if context:
            prompt = f"""### Instruction:
You are a medical AI assistant. Answer the following question based on the provided context.
Be accurate, concise, and cite relevant information from the context.

DISCLAIMER: This is for educational purposes only and should not be considered medical advice.

### Context:
{context}

### Question:
{question}

### Response:
"""
        else:
            prompt = f"""### Instruction:
You are a medical AI assistant. Answer the following question accurately and concisely.

DISCLAIMER: This is for educational purposes only and should not be considered medical advice.

### Question:
{question}

### Response:
"""
        return prompt


# ===== MAIN (for testing) =====
if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Medical LLM Inference")
    parser.add_argument("--base-model", type=str, default="mistralai/Mistral-7B-Instruct-v0.2")
    parser.add_argument("--adapter", type=str, default=None)
    parser.add_argument("--question", type=str, default="What are the symptoms of diabetes?")
    parser.add_argument("--no-4bit", action="store_true")
    
    args = parser.parse_args()
    
    loader = ModelLoader(
        base_model=args.base_model,
        adapter_path=args.adapter,
        load_in_4bit=not args.no_4bit,
    )
    
    prompt = loader.format_medical_prompt(args.question)
    response = loader.generate(prompt)
    
    print("\n" + "=" * 60)
    print(f"Question: {args.question}")
    print("=" * 60)
    print(f"Response: {response}")
    print("=" * 60)
