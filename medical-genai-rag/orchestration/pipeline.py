"""
orchestration/pipeline.py
---------------------------
Central pipeline manager that orchestrates the full RAG flow:
  Ingestion → Embedding → Retrieval → Prompt Building → Generation

Key Concepts:
- Pipeline pattern / Chain of Responsibility
- Modular architecture
- Clear interfaces between components
- Configuration management
"""

import os
import logging
from typing import Optional, Dict, Any, List
from dataclasses import dataclass, field
from pathlib import Path

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@dataclass
class PipelineConfig:
    """Configuration for the entire RAG pipeline."""
    
    # Data
    data_dir: str = "data/raw"
    processed_dir: str = "data/processed"
    index_dir: str = "data/processed/faiss_index"
    
    # Chunking
    chunk_size: int = 512
    chunk_overlap: int = 50
    
    # Embedding
    embedding_model: str = "sentence-transformers/all-MiniLM-L6-v2"
    
    # LLM
    base_model: str = "mistralai/Mistral-7B-Instruct-v0.2"
    adapter_path: Optional[str] = None
    load_in_4bit: bool = True
    
    # Retrieval
    top_k: int = 5
    
    # Generation
    max_new_tokens: int = 512
    temperature: float = 0.7


class RAGPipeline:
    """
    End-to-end RAG pipeline orchestrator.
    
    Architecture:
        1. Document Ingestion → Raw text
        2. Text Chunking → Overlapping chunks
        3. Embedding Generation → Dense vectors
        4. Vector Storage → FAISS index
        5. Query → Retrieve relevant chunks
        6. Prompt Construction → Context-augmented prompt
        7. LLM Generation → Final response
    
    Usage:
        pipeline = RAGPipeline(config)
        pipeline.build_index()  # One-time setup
        response = pipeline.query("What is diabetes?")
    """
    
    def __init__(self, config: Optional[PipelineConfig] = None):
        self.config = config or PipelineConfig()
        
        # Components (lazy loaded)
        self._loader = None
        self._chunker = None
        self._embedder = None
        self._vector_store = None
        self._model_loader = None
        
        # State
        self._index_built = False
        self._model_loaded = False
        
        logger.info("RAGPipeline initialized")
    
    @property
    def loader(self):
        """Lazy-load the document loader."""
        if self._loader is None:
            from ingestion.loader import DocumentLoader
            self._loader = DocumentLoader(self.config.data_dir)
        return self._loader
    
    @property
    def chunker(self):
        """Lazy-load the text chunker."""
        if self._chunker is None:
            from ingestion.chunker import TextChunker
            self._chunker = TextChunker(
                chunk_size=self.config.chunk_size,
                chunk_overlap=self.config.chunk_overlap,
            )
        return self._chunker
    
    @property
    def embedder(self):
        """Lazy-load the text embedder."""
        if self._embedder is None:
            from embeddings.embedder import TextEmbedder
            self._embedder = TextEmbedder(model_name=self.config.embedding_model)
        return self._embedder
    
    @property
    def vector_store(self):
        """Lazy-load the vector store."""
        if self._vector_store is None:
            from embeddings.vector_store import VectorStore
            self._vector_store = VectorStore(dimension=self.embedder.embedding_dim)
        return self._vector_store
    
    @property
    def model_loader(self):
        """Lazy-load the LLM."""
        if self._model_loader is None:
            from inference.model_loader import ModelLoader
            self._model_loader = ModelLoader(
                base_model=self.config.base_model,
                adapter_path=self.config.adapter_path,
                load_in_4bit=self.config.load_in_4bit,
            )
        return self._model_loader
    
    def build_index(self, force: bool = False) -> int:
        """
        Build the FAISS index from documents.
        
        Pipeline: Load → Chunk → Embed → Store
        
        Args:
            force: Rebuild even if index already exists
            
        Returns:
            Number of chunks indexed
        """
        index_path = Path(self.config.index_dir)
        
        # Check if index already exists
        if not force and index_path.exists() and (index_path / "faiss_index.bin").exists():
            logger.info("Loading existing index...")
            self.vector_store.load(str(index_path))
            self._index_built = True
            return self.vector_store.size
        
        logger.info("=" * 60)
        logger.info("BUILDING VECTOR INDEX")
        logger.info("=" * 60)
        
        # Step 1: Load documents
        logger.info("Step 1/4: Loading documents...")
        documents = self.loader.load_all()
        if not documents:
            logger.warning("No documents found! Add files to data/raw/")
            return 0
        
        # Step 2: Chunk documents
        logger.info("Step 2/4: Chunking documents...")
        chunks = self.chunker.chunk_documents(documents)
        
        # Step 3: Generate embeddings
        logger.info("Step 3/4: Generating embeddings...")
        texts = [c["text"] for c in chunks]
        embeddings = self.embedder.embed(texts)
        
        # Step 4: Store in FAISS
        logger.info("Step 4/4: Building FAISS index...")
        metadata = [
            {
                "text": c["text"],
                "source": c["source"],
                "chunk_id": c["chunk_id"],
                "chunk_index": c["chunk_index"],
            }
            for c in chunks
        ]
        self.vector_store.add(embeddings, metadata)
        
        # Save index
        self.vector_store.save(str(index_path))
        
        self._index_built = True
        logger.info(f"Index built: {self.vector_store.size} chunks")
        logger.info("=" * 60)
        
        return self.vector_store.size
    
    def retrieve(self, query: str, top_k: Optional[int] = None) -> List[Dict]:
        """
        Retrieve relevant chunks for a query.
        
        Args:
            query: The search query
            top_k: Number of results (default: config.top_k)
            
        Returns:
            List of result dicts with score and metadata
        """
        if not self._index_built:
            # Try to load existing index
            index_path = Path(self.config.index_dir)
            if index_path.exists() and (index_path / "faiss_index.bin").exists():
                self.vector_store.load(str(index_path))
                self._index_built = True
            else:
                raise RuntimeError("Index not built. Call build_index() first.")
        
        k = top_k or self.config.top_k
        query_embedding = self.embedder.embed_query(query)
        results = self.vector_store.search(query_embedding, top_k=k)
        
        logger.info(f"Retrieved {len(results)} chunks for query: '{query[:50]}...'")
        return results
    
    def query(
        self,
        question: str,
        top_k: Optional[int] = None,
        max_new_tokens: Optional[int] = None,
    ) -> Dict[str, Any]:
        """
        Full RAG query: Retrieve context → Build prompt → Generate response.
        
        Args:
            question: The user's medical question
            top_k: Number of context chunks to retrieve
            max_new_tokens: Max tokens in the response
            
        Returns:
            Dict with 'answer', 'sources', and 'context'
        """
        logger.info(f"Processing query: '{question}'")
        
        # Step 1: Retrieve relevant context
        results = self.retrieve(question, top_k=top_k)
        
        # Step 2: Build context string from retrieved chunks
        context_parts = []
        sources = set()
        for r in results:
            context_parts.append(r["metadata"]["text"])
            sources.add(r["metadata"]["source"])
        
        context = "\n\n---\n\n".join(context_parts)
        
        # Step 3: Format prompt
        prompt = self.model_loader.format_medical_prompt(question, context)
        
        # Step 4: Generate response
        response = self.model_loader.generate(
            prompt,
            max_new_tokens=max_new_tokens or self.config.max_new_tokens,
            temperature=self.config.temperature,
        )
        
        return {
            "answer": response,
            "sources": list(sources),
            "context": context,
            "num_chunks_retrieved": len(results),
        }
    
    def query_without_rag(self, question: str) -> Dict[str, Any]:
        """
        Query the LLM directly without RAG context.
        Useful for comparison with RAG-augmented responses.
        """
        prompt = self.model_loader.format_medical_prompt(question, context="")
        response = self.model_loader.generate(prompt)
        
        return {
            "answer": response,
            "sources": [],
            "context": "",
            "num_chunks_retrieved": 0,
        }


# ===== MAIN (for testing) =====
if __name__ == "__main__":
    config = PipelineConfig()
    pipeline = RAGPipeline(config)
    
    # Build index
    num_chunks = pipeline.build_index()
    print(f"\nIndex contains {num_chunks} chunks")
    
    if num_chunks > 0:
        # Test retrieval
        results = pipeline.retrieve("What is diabetes?")
        print("\nRetrieval results:")
        for r in results:
            print(f"  [{r['rank']}] score={r['score']:.4f}: {r['metadata']['text'][:80]}...")
