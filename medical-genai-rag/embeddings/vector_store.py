"""
embeddings/vector_store.py
---------------------------
FAISS-based vector store for efficient similarity search.

Key Concepts:
- FAISS (Facebook AI Similarity Search)
- Inner product vs L2 distance
- Index persistence (save/load)
- Top-k retrieval
"""

import os
import json
import logging
import numpy as np
from typing import List, Dict, Optional, Tuple
from pathlib import Path

import faiss

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class VectorStore:
    """
    FAISS-based vector store for storing and searching embeddings.
    
    Why FAISS?
    - Extremely fast similarity search
    - Scales to millions of vectors
    - Supports GPU acceleration
    - Industry standard for RAG systems
    
    Usage:
        store = VectorStore(dimension=384)
        store.add(embeddings, metadata_list)
        results = store.search(query_embedding, top_k=5)
    """
    
    def __init__(self, dimension: int = 384):
        """
        Args:
            dimension: Dimensionality of the embedding vectors
        """
        self.dimension = dimension
        # Using Inner Product (cosine sim when vectors are L2-normalized)
        self.index = faiss.IndexFlatIP(dimension)
        self.metadata: List[Dict] = []  # Parallel list of metadata
        
        logger.info(f"VectorStore initialized (dim={dimension})")
    
    def add(self, embeddings: np.ndarray, metadata_list: List[Dict]):
        """
        Add embeddings and their metadata to the store.
        
        Args:
            embeddings: numpy array of shape (n, dimension)
            metadata_list: List of metadata dicts (one per embedding)
        """
        if len(embeddings) != len(metadata_list):
            raise ValueError(
                f"Mismatch: {len(embeddings)} embeddings vs {len(metadata_list)} metadata"
            )
        
        # Ensure float32 for FAISS
        embeddings = np.asarray(embeddings, dtype=np.float32)
        
        self.index.add(embeddings)
        self.metadata.extend(metadata_list)
        
        logger.info(
            f"Added {len(embeddings)} vectors. Total: {self.index.ntotal}"
        )
    
    def search(
        self,
        query_embedding: np.ndarray,
        top_k: int = 5,
    ) -> List[Dict]:
        """
        Search for the most similar vectors to the query.
        
        Args:
            query_embedding: 1D numpy array of the query vector
            top_k: Number of results to return
            
        Returns:
            List of dicts with 'score', 'metadata', and 'rank' keys
        """
        if self.index.ntotal == 0:
            logger.warning("Search called on empty index")
            return []
        
        # Reshape for FAISS (expects 2D)
        query = np.asarray(query_embedding, dtype=np.float32).reshape(1, -1)
        
        # Search
        scores, indices = self.index.search(query, min(top_k, self.index.ntotal))
        
        results = []
        for rank, (score, idx) in enumerate(zip(scores[0], indices[0])):
            if idx == -1:  # FAISS returns -1 for empty slots
                continue
            results.append({
                "rank": rank + 1,
                "score": float(score),
                "metadata": self.metadata[idx],
            })
        
        return results
    
    def save(self, save_dir: str):
        """
        Save the FAISS index and metadata to disk.
        
        Args:
            save_dir: Directory to save index and metadata
        """
        save_path = Path(save_dir)
        save_path.mkdir(parents=True, exist_ok=True)
        
        # Save FAISS index
        index_path = str(save_path / "faiss_index.bin")
        faiss.write_index(self.index, index_path)
        
        # Save metadata as JSON
        meta_path = str(save_path / "metadata.json")
        with open(meta_path, "w") as f:
            json.dump(self.metadata, f, indent=2)
        
        logger.info(f"VectorStore saved to {save_dir} ({self.index.ntotal} vectors)")
    
    def load(self, save_dir: str):
        """
        Load a previously saved FAISS index and metadata.
        
        Args:
            save_dir: Directory containing saved index and metadata
        """
        save_path = Path(save_dir)
        
        # Load FAISS index
        index_path = str(save_path / "faiss_index.bin")
        self.index = faiss.read_index(index_path)
        self.dimension = self.index.d
        
        # Load metadata
        meta_path = str(save_path / "metadata.json")
        with open(meta_path, "r") as f:
            self.metadata = json.load(f)
        
        logger.info(f"VectorStore loaded from {save_dir} ({self.index.ntotal} vectors)")
    
    @property
    def size(self) -> int:
        """Return the number of vectors in the store."""
        return self.index.ntotal


# ===== MAIN (for testing) =====
if __name__ == "__main__":
    # Create a test store
    store = VectorStore(dimension=4)
    
    # Add some dummy vectors
    vectors = np.random.randn(5, 4).astype(np.float32)
    # Normalize
    vectors = vectors / np.linalg.norm(vectors, axis=1, keepdims=True)
    
    metadata = [{"text": f"Document {i}", "source": f"doc{i}.txt"} for i in range(5)]
    store.add(vectors, metadata)
    
    # Search
    query = vectors[0]  # Search for the first document
    results = store.search(query, top_k=3)
    
    print("Search results:")
    for r in results:
        print(f"  Rank {r['rank']}: score={r['score']:.4f} - {r['metadata']['text']}")
