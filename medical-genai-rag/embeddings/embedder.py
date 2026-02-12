"""
embeddings/embedder.py
-----------------------
Generates dense vector embeddings from text chunks using Sentence Transformers.

Key Concepts:
- Dense embeddings vs sparse (TF-IDF)
- Sentence Transformers (SBERT)
- Batch encoding for efficiency
- Embedding dimensionality
"""

import logging
import numpy as np
from typing import List, Optional

from sentence_transformers import SentenceTransformer

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class TextEmbedder:
    """
    Generates embeddings using a pre-trained Sentence Transformer model.
    
    Why Sentence Transformers?
    - Optimized for semantic similarity
    - Fast batch encoding
    - Good out-of-the-box for retrieval
    
    Usage:
        embedder = TextEmbedder()
        vectors = embedder.embed(["text1", "text2"])
    """
    
    def __init__(
        self,
        model_name: str = "sentence-transformers/all-MiniLM-L6-v2",
        device: Optional[str] = None,
    ):
        """
        Args:
            model_name: HuggingFace model ID for the sentence transformer
            device: 'cuda', 'cpu', or None (auto-detect)
        """
        logger.info(f"Loading embedding model: {model_name}")
        self.model = SentenceTransformer(model_name, device=device)
        self.embedding_dim = self.model.get_sentence_embedding_dimension()
        logger.info(f"Embedding model loaded. Dimension: {self.embedding_dim}")
    
    def embed(
        self,
        texts: List[str],
        batch_size: int = 64,
        show_progress: bool = True,
    ) -> np.ndarray:
        """
        Generate embeddings for a list of texts.
        
        Args:
            texts: List of text strings to embed
            batch_size: Number of texts to process at once
            show_progress: Show progress bar
            
        Returns:
            numpy array of shape (num_texts, embedding_dim)
        """
        if not texts:
            return np.array([])
        
        logger.info(f"Embedding {len(texts)} texts (batch_size={batch_size})")
        
        embeddings = self.model.encode(
            texts,
            batch_size=batch_size,
            show_progress_bar=show_progress,
            normalize_embeddings=True,  # L2 normalize for cosine similarity
        )
        
        logger.info(f"Generated embeddings: shape={embeddings.shape}")
        return embeddings
    
    def embed_query(self, query: str) -> np.ndarray:
        """
        Embed a single query string.
        
        Args:
            query: The search query text
            
        Returns:
            1D numpy array of the query embedding
        """
        return self.model.encode(
            [query],
            normalize_embeddings=True,
        )[0]


# ===== MAIN (for testing) =====
if __name__ == "__main__":
    embedder = TextEmbedder()
    
    test_texts = [
        "Diabetes is a chronic metabolic disorder.",
        "Hypertension is a major risk factor for cardiovascular disease.",
        "Machine learning can assist in medical diagnosis.",
    ]
    
    embeddings = embedder.embed(test_texts)
    print(f"Embeddings shape: {embeddings.shape}")
    
    # Test similarity
    from numpy import dot
    sim = dot(embeddings[0], embeddings[1])
    print(f"Similarity (diabetes vs hypertension): {sim:.4f}")
    sim2 = dot(embeddings[0], embeddings[2])
    print(f"Similarity (diabetes vs ML): {sim2:.4f}")
