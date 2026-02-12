#!/usr/bin/env python3
"""Test inference with the fine-tuned LoRA adapter."""
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import torch
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def test_inference():
    """Test model inference with and without adapter."""
    from transformers import AutoModelForCausalLM, AutoTokenizer, BitsAndBytesConfig
    from peft import PeftModel
    
    base_model_name = "mistralai/Mistral-7B-Instruct-v0.2"
    adapter_path = "./finetuning/outputs/final_adapter"
    
    logger.info("Loading tokenizer...")
    tokenizer = AutoTokenizer.from_pretrained(base_model_name)
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token
    
    logger.info("Loading base model with 4-bit quantization...")
    bnb_config = BitsAndBytesConfig(
        load_in_4bit=True,
        bnb_4bit_quant_type="nf4",
        bnb_4bit_compute_dtype=torch.bfloat16,
        bnb_4bit_use_double_quant=True,
    )
    
    model = AutoModelForCausalLM.from_pretrained(
        base_model_name,
        quantization_config=bnb_config,
        device_map="auto",
    )
    
    logger.info("Loading LoRA adapter...")
    model = PeftModel.from_pretrained(model, adapter_path)
    model.eval()
    
    logger.info("=" * 60)
    logger.info("INFERENCE TEST")
    logger.info("=" * 60)
    
    # Test questions
    questions = [
        "What are the common symptoms of Type 2 Diabetes?",
        "How do ACE inhibitors work in treating hypertension?",
        "What is diabetic ketoacidosis and how is it managed?",
    ]
    
    for q in questions:
        logger.info(f"\nQuestion: {q}")
        
        prompt = f"[INST] You are a knowledgeable medical assistant. Provide accurate, evidence-based medical information.\n\n{q} [/INST]"
        
        inputs = tokenizer(prompt, return_tensors="pt").to(model.device)
        
        with torch.no_grad():
            outputs = model.generate(
                **inputs,
                max_new_tokens=256,
                temperature=0.7,
                top_p=0.9,
                do_sample=True,
                repetition_penalty=1.1,
            )
        
        response = tokenizer.decode(outputs[0][inputs['input_ids'].shape[1]:], skip_special_tokens=True)
        logger.info(f"Response: {response[:500]}")
        logger.info("-" * 60)
    
    logger.info("\nInference test completed successfully!")

if __name__ == "__main__":
    test_inference()
