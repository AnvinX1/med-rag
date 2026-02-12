"""
ingestion/loader.py
--------------------
Handles loading of medical documents (PDFs and text files).
Extracts raw text from various file formats for downstream processing.

Key Concepts:
- File I/O in Python
- PDF parsing with PyPDF2 and PyMuPDF (fitz)
- Error handling and logging
"""

import os
import logging
from pathlib import Path
from typing import List, Dict, Optional

# PyMuPDF for robust PDF parsing
import fitz  # PyMuPDF

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class DocumentLoader:
    """
    Loads medical documents from a directory.
    Supports: PDF, TXT, MD files.
    
    Usage:
        loader = DocumentLoader("data/raw")
        documents = loader.load_all()
    """
    
    SUPPORTED_EXTENSIONS = {".pdf", ".txt", ".md"}
    
    def __init__(self, data_dir: str):
        """
        Initialize the loader with a data directory path.
        
        Args:
            data_dir: Path to directory containing medical documents
        """
        self.data_dir = Path(data_dir)
        if not self.data_dir.exists():
            logger.warning(f"Data directory does not exist: {self.data_dir}")
            self.data_dir.mkdir(parents=True, exist_ok=True)
            logger.info(f"Created data directory: {self.data_dir}")
    
    def load_pdf(self, file_path: str) -> str:
        """
        Extract text from a PDF file using PyMuPDF.
        
        Args:
            file_path: Path to the PDF file
            
        Returns:
            Extracted text as a single string
        """
        try:
            doc = fitz.open(file_path)
            text_parts = []
            for page_num in range(len(doc)):
                page = doc.load_page(page_num)
                text_parts.append(page.get_text())
            doc.close()
            
            full_text = "\n".join(text_parts)
            logger.info(f"Loaded PDF: {file_path} ({len(full_text)} chars, {len(doc)} pages)")
            return full_text
            
        except Exception as e:
            logger.error(f"Failed to load PDF {file_path}: {e}")
            return ""
    
    def load_text(self, file_path: str) -> str:
        """
        Load a plain text or markdown file.
        
        Args:
            file_path: Path to the text file
            
        Returns:
            File contents as a string
        """
        try:
            with open(file_path, "r", encoding="utf-8") as f:
                text = f.read()
            logger.info(f"Loaded text file: {file_path} ({len(text)} chars)")
            return text
            
        except Exception as e:
            logger.error(f"Failed to load text file {file_path}: {e}")
            return ""
    
    def load_single(self, file_path: str) -> Dict:
        """
        Load a single document and return structured output.
        
        Args:
            file_path: Path to the document
            
        Returns:
            Dictionary with 'source', 'text', and 'type' keys
        """
        path = Path(file_path)
        extension = path.suffix.lower()
        
        if extension == ".pdf":
            text = self.load_pdf(file_path)
        elif extension in {".txt", ".md"}:
            text = self.load_text(file_path)
        else:
            logger.warning(f"Unsupported file type: {extension}")
            return {"source": str(file_path), "text": "", "type": "unknown"}
        
        return {
            "source": str(file_path),
            "text": text,
            "type": extension.replace(".", ""),
        }
    
    def load_all(self) -> List[Dict]:
        """
        Load all supported documents from the data directory.
        
        Returns:
            List of document dictionaries
        """
        documents = []
        
        for file_path in sorted(self.data_dir.rglob("*")):
            if file_path.suffix.lower() in self.SUPPORTED_EXTENSIONS:
                doc = self.load_single(str(file_path))
                if doc["text"]:  # Only include non-empty documents
                    documents.append(doc)
        
        logger.info(f"Loaded {len(documents)} documents from {self.data_dir}")
        return documents


# ===== MAIN (for testing) =====
if __name__ == "__main__":
    loader = DocumentLoader("data/raw")
    docs = loader.load_all()
    for doc in docs:
        print(f"  [{doc['type']}] {doc['source']} - {len(doc['text'])} chars")
