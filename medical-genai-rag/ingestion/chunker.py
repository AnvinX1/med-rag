"""
ingestion/chunker.py
---------------------
Splits large documents into smaller, overlapping chunks for embedding.

Key Concepts:
- Text splitting strategies
- Chunk size vs. overlap tradeoffs
- Maintaining context across chunks
"""

import logging
from typing import List, Dict

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class TextChunker:
    """
    Splits document text into overlapping chunks for embedding and retrieval.
    
    Why chunking?
    - LLMs have limited context windows
    - Smaller chunks = more precise retrieval
    - Overlap ensures no information is lost at boundaries
    
    Usage:
        chunker = TextChunker(chunk_size=512, chunk_overlap=50)
        chunks = chunker.chunk_documents(documents)
    """
    
    def __init__(self, chunk_size: int = 512, chunk_overlap: int = 50):
        """
        Args:
            chunk_size: Maximum number of characters per chunk
            chunk_overlap: Number of overlapping characters between chunks
        """
        self.chunk_size = chunk_size
        self.chunk_overlap = chunk_overlap
        
        if chunk_overlap >= chunk_size:
            raise ValueError("chunk_overlap must be less than chunk_size")
        
        logger.info(f"TextChunker initialized: size={chunk_size}, overlap={chunk_overlap}")
    
    def chunk_text(self, text: str) -> List[str]:
        """
        Split a single text into overlapping chunks.
        
        Strategy:
        1. Try to split on paragraph boundaries first
        2. Fall back to sentence boundaries
        3. Last resort: split at character level
        
        Args:
            text: The raw text to chunk
            
        Returns:
            List of text chunks
        """
        if not text or not text.strip():
            return []
        
        # Clean up the text
        text = text.strip()
        
        chunks = []
        start = 0
        
        while start < len(text):
            # Calculate end position
            end = start + self.chunk_size
            
            if end >= len(text):
                # Last chunk - take everything remaining
                chunks.append(text[start:].strip())
                break
            
            # Try to find a good split point (paragraph, sentence, or word boundary)
            split_point = self._find_split_point(text, start, end)
            
            chunk = text[start:split_point].strip()
            if chunk:  # Only add non-empty chunks
                chunks.append(chunk)
            
            # Move start forward, accounting for overlap
            start = split_point - self.chunk_overlap
            if start <= 0 or start <= (split_point - self.chunk_size):
                start = split_point  # Prevent infinite loop
        
        return chunks
    
    def _find_split_point(self, text: str, start: int, end: int) -> int:
        """
        Find the best position to split text, preferring natural boundaries.
        
        Priority: paragraph > sentence > word > character
        """
        # Look for paragraph break (double newline)
        para_break = text.rfind("\n\n", start + self.chunk_size // 2, end)
        if para_break != -1:
            return para_break + 2  # Include the newlines
        
        # Look for sentence end (period + space)
        for sep in [". ", ".\n", "? ", "! "]:
            sent_break = text.rfind(sep, start + self.chunk_size // 2, end)
            if sent_break != -1:
                return sent_break + len(sep)
        
        # Look for word boundary (space)
        space = text.rfind(" ", start + self.chunk_size // 2, end)
        if space != -1:
            return space + 1
        
        # Last resort: hard cut
        return end
    
    def chunk_documents(self, documents: List[Dict]) -> List[Dict]:
        """
        Chunk a list of documents, preserving metadata.
        
        Args:
            documents: List of dicts with 'text', 'source', 'type' keys
            
        Returns:
            List of chunk dicts with added 'chunk_id' and 'chunk_index'
        """
        all_chunks = []
        chunk_id = 0
        
        for doc in documents:
            text = doc.get("text", "")
            chunks = self.chunk_text(text)
            
            for idx, chunk_text in enumerate(chunks):
                all_chunks.append({
                    "chunk_id": chunk_id,
                    "chunk_index": idx,
                    "text": chunk_text,
                    "source": doc.get("source", "unknown"),
                    "type": doc.get("type", "unknown"),
                    "total_chunks": len(chunks),
                })
                chunk_id += 1
        
        logger.info(
            f"Chunked {len(documents)} documents into {len(all_chunks)} chunks "
            f"(avg {len(all_chunks) / max(len(documents), 1):.1f} chunks/doc)"
        )
        return all_chunks


# ===== MAIN (for testing) =====
if __name__ == "__main__":
    # Test with sample text
    sample_docs = [
        {
            "text": "Diabetes mellitus is a metabolic disorder. " * 50,
            "source": "test.txt",
            "type": "txt",
        }
    ]
    
    chunker = TextChunker(chunk_size=200, chunk_overlap=30)
    chunks = chunker.chunk_documents(sample_docs)
    
    for chunk in chunks[:3]:
        print(f"  Chunk {chunk['chunk_id']}: {len(chunk['text'])} chars")
        print(f"    '{chunk['text'][:80]}...'")
