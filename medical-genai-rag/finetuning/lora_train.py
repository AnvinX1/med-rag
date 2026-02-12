"""
finetuning/lora_train.py
-------------------------
Fine-tunes a small LLM (Mistral-7B or similar) using LoRA/QLoRA.

Key Concepts:
- LoRA: Low-Rank Adaptation (adds small trainable matrices)
- QLoRA: Quantized LoRA (4-bit base model + LoRA adapters)
- PEFT: Parameter-Efficient Fine-Tuning library
- BitsAndBytes: Quantization library
- SFTTrainer: Supervised Fine-Tuning Trainer from TRL
"""

import os
import json
import logging
import torch
from pathlib import Path
from typing import Optional
from dataclasses import dataclass, field

from datasets import load_dataset, Dataset
from transformers import (
    AutoModelForCausalLM,
    AutoTokenizer,
    BitsAndBytesConfig,
)
from peft import (
    LoraConfig,
    get_peft_model,
    prepare_model_for_kbit_training,
    TaskType,
)
from trl import SFTTrainer, SFTConfig

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@dataclass
class FineTuneConfig:
    """Configuration for fine-tuning."""
    
    # Model
    base_model: str = "mistralai/Mistral-7B-Instruct-v0.2"
    
    # LoRA hyperparameters
    lora_r: int = 16                 # Rank of LoRA matrices
    lora_alpha: int = 32             # Scaling factor
    lora_dropout: float = 0.05       # Dropout for LoRA layers
    target_modules: list = field(default_factory=lambda: [
        "q_proj", "k_proj", "v_proj", "o_proj",
        "gate_proj", "up_proj", "down_proj",
    ])
    
    # Quantization
    use_4bit: bool = True            # Use 4-bit quantization
    bnb_4bit_compute_dtype: str = "bfloat16"
    bnb_4bit_quant_type: str = "nf4"  # Normal Float 4
    use_double_quant: bool = True     # Nested quantization
    
    # Training
    output_dir: str = "./finetuning/outputs"
    num_train_epochs: int = 3
    per_device_train_batch_size: int = 4
    gradient_accumulation_steps: int = 4
    learning_rate: float = 2e-4
    max_seq_length: int = 1024
    warmup_steps: int = 2
    lr_scheduler_type: str = "cosine"
    logging_steps: int = 10
    save_steps: int = 100
    bf16: bool = True
    
    # Dataset
    dataset_path: str = "data/processed/finetune_data.json"
    
    def to_dict(self):
        return {k: str(v) if isinstance(v, list) else v for k, v in self.__dict__.items()}


def create_medical_dataset(output_path: str = "data/processed/finetune_data.json"):
    """
    Create a sample medical Q&A dataset for fine-tuning.
    In production, this would be replaced with real medical data.
    """
    samples = [
        {
            "instruction": "What are the common symptoms of Type 2 Diabetes?",
            "input": "",
            "output": "Common symptoms of Type 2 Diabetes include increased thirst (polydipsia), frequent urination (polyuria), increased hunger (polyphagia), unintended weight loss, fatigue, blurred vision, slow-healing sores, frequent infections, and areas of darkened skin (acanthosis nigricans). Many people with Type 2 Diabetes may have no symptoms initially, which is why regular screening is important for those at risk."
        },
        {
            "instruction": "Explain the mechanism of action of metformin.",
            "input": "",
            "output": "Metformin is a biguanide antihyperglycemic agent that works primarily by: 1) Decreasing hepatic glucose production by inhibiting gluconeogenesis and glycogenolysis, 2) Increasing insulin sensitivity in peripheral tissues, particularly skeletal muscle, enhancing glucose uptake and utilization, 3) Reducing intestinal absorption of glucose, and 4) Activating AMP-activated protein kinase (AMPK), which plays a key role in cellular energy homeostasis. Unlike sulfonylureas, metformin does not stimulate insulin secretion, so it does not typically cause hypoglycemia when used as monotherapy."
        },
        {
            "instruction": "What is the difference between systolic and diastolic blood pressure?",
            "input": "",
            "output": "Systolic blood pressure (the top number) measures the pressure in your arteries when your heart beats and pumps blood out. Diastolic blood pressure (the bottom number) measures the pressure in your arteries when your heart rests between beats. Normal blood pressure is typically below 120/80 mmHg. Systolic hypertension (high systolic with normal diastolic) is more common in older adults and is a significant risk factor for cardiovascular disease. Both numbers are important for assessing cardiovascular risk."
        },
        {
            "instruction": "Describe the pathophysiology of asthma.",
            "input": "",
            "output": "Asthma is a chronic inflammatory disorder of the airways characterized by: 1) Airway inflammation - involving mast cells, eosinophils, T lymphocytes, and other inflammatory mediators, leading to airway edema and mucus hypersecretion, 2) Airway hyperresponsiveness - exaggerated bronchoconstrictor response to various stimuli including allergens, exercise, cold air, and irritants, 3) Airway remodeling - chronic inflammation leads to structural changes including subepithelial fibrosis, smooth muscle hypertrophy, angiogenesis, and mucous gland hyperplasia, 4) Variable airflow obstruction - resulting from bronchospasm, mucosal edema, mucus plugging, and airway remodeling. The inflammatory cascade involves IgE-mediated reactions and Th2 cytokine release."
        },
        {
            "instruction": "What are the stages of chronic kidney disease (CKD)?",
            "input": "",
            "output": "Chronic Kidney Disease is classified into 5 stages based on the Glomerular Filtration Rate (GFR): Stage 1 (GFR ≥90 mL/min): Normal or high GFR with evidence of kidney damage (e.g., proteinuria). Stage 2 (GFR 60-89 mL/min): Mildly decreased GFR with kidney damage. Stage 3a (GFR 45-59 mL/min): Mild to moderately decreased GFR. Stage 3b (GFR 30-44 mL/min): Moderately to severely decreased GFR. Stage 4 (GFR 15-29 mL/min): Severely decreased GFR. Stage 5 (GFR <15 mL/min): Kidney failure (end-stage renal disease), typically requiring dialysis or transplantation. Management becomes increasingly intensive with each stage."
        },
        {
            "instruction": "Explain how vaccines work to provide immunity.",
            "input": "",
            "output": "Vaccines work by training the immune system to recognize and fight specific pathogens without causing the actual disease. The process involves: 1) Introduction of antigens - vaccines contain weakened/inactivated pathogens, protein subunits, or mRNA encoding pathogen proteins, 2) Innate immune response - antigen-presenting cells (APCs) like dendritic cells process the vaccine antigens, 3) Adaptive immune response - APCs present antigens to T cells and B cells, activating cellular and humoral immunity, 4) B cell activation produces antibodies specific to the pathogen, 5) Memory cell formation - both memory B cells and memory T cells are created, providing long-lasting immunity, 6) Upon future exposure to the actual pathogen, memory cells mount a rapid, strong immune response, preventing or reducing disease severity."
        },
        {
            "instruction": "What is the role of cholesterol in cardiovascular disease?",
            "input": "",
            "output": "Cholesterol plays a central role in cardiovascular disease through atherosclerosis: 1) LDL cholesterol ('bad cholesterol') can penetrate and accumulate in arterial walls, 2) Oxidized LDL triggers an inflammatory response, attracting macrophages that engulf the lipids and become foam cells, 3) Foam cells accumulate to form fatty streaks, the earliest visible lesion of atherosclerosis, 4) Over time, smooth muscle cells migrate and proliferate, forming a fibrous cap over the lipid core, creating atherosclerotic plaques, 5) Plaques can narrow arteries (causing angina) or rupture (causing thrombosis, potentially leading to heart attack or stroke), 6) HDL cholesterol ('good cholesterol') helps remove cholesterol from arterial walls through reverse cholesterol transport. Statins reduce cardiovascular risk primarily by lowering LDL levels."
        },
        {
            "instruction": "Describe the Glasgow Coma Scale and its clinical significance.",
            "input": "",
            "output": "The Glasgow Coma Scale (GCS) is a clinical scale used to assess the level of consciousness in patients with acute brain injury. It evaluates three components: Eye Opening (E): Spontaneous=4, To voice=3, To pressure=2, None=1. Verbal Response (V): Oriented=5, Confused=4, Inappropriate words=3, Incomprehensible sounds=2, None=1. Motor Response (M): Obeys commands=6, Localizing pain=5, Normal flexion=4, Abnormal flexion=3, Extension=2, None=1. Total GCS ranges from 3 (deep coma) to 15 (fully alert). Clinical significance: Mild brain injury: GCS 13-15, Moderate: 9-12, Severe: 3-8 (intubation typically required). GCS is used for triage, prognosis, and monitoring neurological status."
        },
        {
            "instruction": "What are the main classes of antibiotics and their mechanisms?",
            "input": "",
            "output": "The main classes of antibiotics include: 1) Beta-lactams (penicillins, cephalosporins, carbapenems) - inhibit cell wall synthesis by binding penicillin-binding proteins, 2) Aminoglycosides (gentamicin, tobramycin) - bind 30S ribosomal subunit, causing misreading of mRNA and inhibiting protein synthesis, 3) Macrolides (azithromycin, erythromycin) - bind 50S ribosomal subunit, inhibiting translocation during protein synthesis, 4) Fluoroquinolones (ciprofloxacin, levofloxacin) - inhibit DNA gyrase and topoisomerase IV, preventing DNA replication, 5) Tetracyclines - bind 30S ribosomal subunit, blocking aminoacyl-tRNA binding, 6) Glycopeptides (vancomycin) - bind D-Ala-D-Ala terminus of peptidoglycan precursors, inhibiting cell wall synthesis, 7) Sulfonamides/Trimethoprim - inhibit folate synthesis pathway."
        },
        {
            "instruction": "Explain the difference between Type 1 and Type 2 Diabetes Mellitus.",
            "input": "",
            "output": "Type 1 and Type 2 Diabetes differ in pathophysiology and management: Type 1 DM: Autoimmune destruction of pancreatic beta cells leading to absolute insulin deficiency. Typically presents in children/young adults. Patients require exogenous insulin for survival. Associated with HLA-DR3/DR4 and autoantibodies (GAD65, IA-2). Accounts for 5-10% of diabetes cases. Type 2 DM: Characterized by insulin resistance and relative insulin deficiency. Typically presents in adults (increasingly in youth due to obesity). Strong association with obesity, sedentary lifestyle, and family history. Initial management includes lifestyle modifications and oral hypoglycemics (metformin first-line). May eventually require insulin. Accounts for 90-95% of diabetes cases. Both types lead to chronic complications including retinopathy, nephropathy, neuropathy, and cardiovascular disease."
        },
    ]
    
    # Format for instruction fine-tuning
    formatted = []
    for s in samples:
        text = f"""### Instruction:
{s['instruction']}

### Response:
{s['output']}"""
        formatted.append({"text": text})
    
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, "w") as f:
        json.dump(formatted, f, indent=2)
    
    logger.info(f"Created {len(formatted)} training samples at {output_path}")
    return output_path


class LoRAFineTuner:
    """
    Fine-tunes an LLM using LoRA/QLoRA.
    
    LoRA (Low-Rank Adaptation):
    - Instead of fine-tuning all model weights, LoRA adds small trainable
      matrices (adapters) to specific layers
    - Greatly reduces memory and compute requirements
    - Adapters can be saved separately (small file size)
    
    QLoRA:
    - Quantizes base model to 4-bit (NF4)
    - Trains LoRA adapters in float16
    - Enables fine-tuning of large models on consumer GPUs
    
    Usage:
        config = FineTuneConfig(base_model="mistralai/Mistral-7B-Instruct-v0.2")
        trainer = LoRAFineTuner(config)
        trainer.train()
    """
    
    def __init__(self, config: Optional[FineTuneConfig] = None):
        self.config = config or FineTuneConfig()
        self.model = None
        self.tokenizer = None
        self.trainer = None
    
    def setup_quantization(self) -> BitsAndBytesConfig:
        """
        Configure 4-bit quantization for QLoRA.
        
        NF4 (Normal Float 4):
        - Optimal data type for normally distributed weights
        - Better than standard int4 for neural networks
        """
        compute_dtype = getattr(torch, self.config.bnb_4bit_compute_dtype)
        
        bnb_config = BitsAndBytesConfig(
            load_in_4bit=self.config.use_4bit,
            bnb_4bit_quant_type=self.config.bnb_4bit_quant_type,
            bnb_4bit_compute_dtype=compute_dtype,
            bnb_4bit_use_double_quant=self.config.use_double_quant,
        )
        
        logger.info(f"Quantization config: 4-bit={self.config.use_4bit}, "
                     f"type={self.config.bnb_4bit_quant_type}")
        return bnb_config
    
    def load_model(self):
        """
        Load the base model with quantization and apply LoRA adapters.
        """
        logger.info(f"Loading base model: {self.config.base_model}")
        
        # Check GPU availability
        if torch.cuda.is_available():
            logger.info(f"GPU: {torch.cuda.get_device_name(0)}")
            logger.info(f"GPU Memory: {torch.cuda.get_device_properties(0).total_memory / 1e9:.1f} GB")
        else:
            logger.warning("No GPU detected! Fine-tuning will be very slow.")
        
        # Setup quantization
        bnb_config = self.setup_quantization()
        
        # Load tokenizer
        self.tokenizer = AutoTokenizer.from_pretrained(
            self.config.base_model,
            trust_remote_code=True,
        )
        self.tokenizer.pad_token = self.tokenizer.eos_token
        self.tokenizer.padding_side = "right"
        
        # Load model with quantization
        self.model = AutoModelForCausalLM.from_pretrained(
            self.config.base_model,
            quantization_config=bnb_config,
            device_map="auto",
            trust_remote_code=True,
        )
        self.model.config.use_cache = False  # Required for gradient checkpointing
        
        # Prepare for k-bit training
        self.model = prepare_model_for_kbit_training(self.model)
        
        # Configure LoRA
        lora_config = LoraConfig(
            r=self.config.lora_r,
            lora_alpha=self.config.lora_alpha,
            lora_dropout=self.config.lora_dropout,
            target_modules=self.config.target_modules,
            bias="none",
            task_type=TaskType.CAUSAL_LM,
        )
        
        # Apply LoRA
        self.model = get_peft_model(self.model, lora_config)
        
        # Log trainable parameters
        trainable, total = self.model.get_nb_trainable_parameters()
        logger.info(
            f"Trainable params: {trainable:,} / {total:,} "
            f"({100 * trainable / total:.2f}%)"
        )
    
    def load_dataset(self) -> Dataset:
        """
        Load the fine-tuning dataset.
        """
        dataset_path = self.config.dataset_path
        
        if not os.path.exists(dataset_path):
            logger.info("Dataset not found, creating sample dataset...")
            create_medical_dataset(dataset_path)
        
        dataset = load_dataset("json", data_files=dataset_path, split="train")
        logger.info(f"Loaded dataset: {len(dataset)} samples")
        return dataset
    
    def train(self):
        """
        Run the full fine-tuning pipeline.
        """
        logger.info("=" * 60)
        logger.info("STARTING FINE-TUNING PIPELINE")
        logger.info("=" * 60)
        
        # Load model
        self.load_model()
        
        # Load dataset
        dataset = self.load_dataset()
        
        # Training arguments using SFTConfig (TRL v0.28+)
        sft_config = SFTConfig(
            output_dir=self.config.output_dir,
            num_train_epochs=self.config.num_train_epochs,
            per_device_train_batch_size=self.config.per_device_train_batch_size,
            gradient_accumulation_steps=self.config.gradient_accumulation_steps,
            learning_rate=self.config.learning_rate,
            bf16=self.config.bf16,
            logging_steps=self.config.logging_steps,
            save_steps=self.config.save_steps,
            warmup_steps=self.config.warmup_steps,
            lr_scheduler_type=self.config.lr_scheduler_type,
            optim="paged_adamw_32bit",
            gradient_checkpointing=True,
            report_to="none",  # Disable wandb etc
            save_total_limit=2,
            max_length=self.config.max_seq_length,
            dataset_text_field="text",
        )
        
        # Create SFT Trainer
        self.trainer = SFTTrainer(
            model=self.model,
            train_dataset=dataset,
            processing_class=self.tokenizer,
            args=sft_config,
        )
        
        # Train!
        logger.info("Starting training...")
        self.trainer.train()
        
        # Save the fine-tuned adapter
        adapter_path = os.path.join(self.config.output_dir, "final_adapter")
        self.model.save_pretrained(adapter_path)
        self.tokenizer.save_pretrained(adapter_path)
        
        logger.info(f"Training complete! Adapter saved to: {adapter_path}")
        logger.info("=" * 60)
        
        return adapter_path


# ===== MAIN =====
if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Fine-tune LLM with LoRA/QLoRA")
    parser.add_argument("--base-model", type=str, default="mistralai/Mistral-7B-Instruct-v0.2")
    parser.add_argument("--epochs", type=int, default=3)
    parser.add_argument("--batch-size", type=int, default=4)
    parser.add_argument("--lr", type=float, default=2e-4)
    parser.add_argument("--lora-r", type=int, default=16)
    parser.add_argument("--output-dir", type=str, default="./finetuning/outputs")
    parser.add_argument("--dataset", type=str, default="data/processed/finetune_data.json")
    parser.add_argument("--create-dataset", action="store_true", help="Create sample dataset only")
    
    args = parser.parse_args()
    
    if args.create_dataset:
        create_medical_dataset(args.dataset)
    else:
        config = FineTuneConfig(
            base_model=args.base_model,
            num_train_epochs=args.epochs,
            per_device_train_batch_size=args.batch_size,
            learning_rate=args.lr,
            lora_r=args.lora_r,
            output_dir=args.output_dir,
            dataset_path=args.dataset,
        )
        
        tuner = LoRAFineTuner(config)
        tuner.train()
