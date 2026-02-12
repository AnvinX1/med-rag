"""
ingestion/__init__.py
"""
from ingestion.loader import DocumentLoader
from ingestion.chunker import TextChunker

__all__ = ["DocumentLoader", "TextChunker"]
