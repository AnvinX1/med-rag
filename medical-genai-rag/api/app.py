"""
api/app.py
-----------
FastAPI-based REST API for the Medical GenAI RAG system.

Key Concepts:
- FastAPI framework
- Pydantic request/response models
- Dependency injection
- Async endpoints
- Health checks
"""

import os
import sys
import time
import logging
import psutil
import datetime
from typing import Optional, List, Dict, Any
from contextlib import asynccontextmanager
from collections import deque

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

# Add project root to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from orchestration.pipeline import RAGPipeline, PipelineConfig

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


# ===== Pydantic Models =====

class AskRequest(BaseModel):
    """Request model for the /ask endpoint."""
    question: str = Field(..., description="The medical question to ask", min_length=3)
    top_k: Optional[int] = Field(5, description="Number of context chunks to retrieve")
    max_new_tokens: Optional[int] = Field(512, description="Max tokens in response")
    use_rag: Optional[bool] = Field(True, description="Whether to use RAG context")


class AskResponse(BaseModel):
    """Response model for the /ask endpoint."""
    answer: str
    sources: List[str]
    num_chunks_retrieved: int
    processing_time_seconds: float
    disclaimer: str = (
        "⚠️ DISCLAIMER: This system is for educational and research purposes only. "
        "It does NOT provide medical advice. Always consult a qualified healthcare professional."
    )


class HealthResponse(BaseModel):
    """Response model for health check."""
    status: str
    index_size: int
    model_loaded: bool


class IndexResponse(BaseModel):
    """Response model for index building."""
    status: str
    num_chunks: int
    message: str


# ===== App Setup =====

# Global pipeline instance
pipeline: Optional[RAGPipeline] = None

# ===== Metrics Tracking =====
_start_time = time.time()
_request_log: deque = deque(maxlen=200)
_query_count = 0
_error_count = 0
_total_latency = 0.0


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan - setup and teardown."""
    global pipeline
    
    logger.info("Starting Medical GenAI RAG API...")
    
    # Initialize pipeline
    config = PipelineConfig(
        data_dir=os.environ.get("DATA_DIR", "data/raw"),
        base_model=os.environ.get("BASE_MODEL", "mistralai/Mistral-7B-Instruct-v0.2"),
        adapter_path=os.environ.get("ADAPTER_PATH", None),
    )
    pipeline = RAGPipeline(config)
    
    # Try to load existing index
    try:
        pipeline.build_index(force=False)
        logger.info("Index loaded successfully")
    except Exception as e:
        logger.warning(f"Could not load index: {e}. Build it via POST /index")
    
    logger.info("API ready!")
    yield
    
    logger.info("Shutting down...")


app = FastAPI(
    title="Medical GenAI RAG API",
    description=(
        "A Retrieval-Augmented Generation system for medical queries. "
        "Uses FAISS for retrieval and a fine-tuned LLM for generation."
    ),
    version="1.0.0",
    lifespan=lifespan,
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ===== Endpoints =====

@app.get("/", tags=["General"])
async def root():
    """Root endpoint with API info."""
    return {
        "name": "Medical GenAI RAG API",
        "version": "1.0.0",
        "endpoints": ["/ask", "/health", "/index"],
        "docs": "/docs",
    }


@app.get("/health", response_model=HealthResponse, tags=["General"])
async def health_check():
    """Check system health and component status."""
    return HealthResponse(
        status="healthy",
        index_size=pipeline.vector_store.size if pipeline and pipeline._index_built else 0,
        model_loaded=pipeline._model_loaded if pipeline else False,
    )


@app.post("/ask", response_model=AskResponse, tags=["RAG"])
async def ask_question(request: AskRequest):
    """
    Ask a medical question.
    
    The system retrieves relevant context from indexed medical documents
    and generates a grounded response using the LLM.
    """
    if not pipeline:
        raise HTTPException(status_code=503, detail="Pipeline not initialized")
    
    start_time = time.time()
    
    try:
        if request.use_rag:
            result = pipeline.query(
                question=request.question,
                top_k=request.top_k,
                max_new_tokens=request.max_new_tokens,
            )
        else:
            result = pipeline.query_without_rag(request.question)
        
        elapsed = time.time() - start_time
        
        # Track metrics
        global _query_count, _total_latency
        _query_count += 1
        _total_latency += elapsed
        _request_log.append({
            "timestamp": datetime.datetime.utcnow().isoformat(),
            "question": request.question[:80],
            "latency": round(elapsed, 2),
            "chunks": result["num_chunks_retrieved"],
            "status": "success",
        })
        
        return AskResponse(
            answer=result["answer"],
            sources=result["sources"],
            num_chunks_retrieved=result["num_chunks_retrieved"],
            processing_time_seconds=round(elapsed, 2),
        )
    
    except Exception as e:
        global _error_count
        _error_count += 1
        _request_log.append({
            "timestamp": datetime.datetime.utcnow().isoformat(),
            "question": request.question[:80],
            "latency": round(time.time() - start_time, 2),
            "status": "error",
            "error": str(e)[:100],
        })
        logger.error(f"Error processing query: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/index", response_model=IndexResponse, tags=["Admin"])
async def build_index(force: bool = False):
    """
    Build or rebuild the FAISS vector index from documents in data/raw/.
    """
    if not pipeline:
        raise HTTPException(status_code=503, detail="Pipeline not initialized")
    
    try:
        num_chunks = pipeline.build_index(force=force)
        return IndexResponse(
            status="success",
            num_chunks=num_chunks,
            message=f"Index built with {num_chunks} chunks",
        )
    except Exception as e:
        logger.error(f"Error building index: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/retrieve", tags=["RAG"])
async def retrieve_chunks(question: str, top_k: int = 5):
    """
    Retrieve relevant document chunks without generating a response.
    Useful for debugging and understanding what context the RAG retrieves.
    """
    if not pipeline:
        raise HTTPException(status_code=503, detail="Pipeline not initialized")
    
    try:
        results = pipeline.retrieve(question, top_k=top_k)
        return {
            "question": question,
            "results": [
                {
                    "rank": r["rank"],
                    "score": r["score"],
                    "text": r["metadata"]["text"],
                    "source": r["metadata"]["source"],
                }
                for r in results
            ],
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ===== Monitoring Endpoints =====

def _get_gpu_info() -> List[Dict[str, Any]]:
    """Get GPU metrics via nvidia-smi."""
    try:
        import subprocess
        result = subprocess.run(
            ["nvidia-smi", "--query-gpu=index,name,memory.used,memory.total,utilization.gpu,temperature.gpu,power.draw",
             "--format=csv,noheader,nounits"],
            capture_output=True, text=True, timeout=5,
        )
        gpus = []
        for line in result.stdout.strip().split("\n"):
            parts = [p.strip() for p in line.split(",")]
            if len(parts) >= 7:
                gpus.append({
                    "index": int(parts[0]),
                    "name": parts[1],
                    "memory_used_mb": float(parts[2]),
                    "memory_total_mb": float(parts[3]),
                    "memory_percent": round(float(parts[2]) / float(parts[3]) * 100, 1),
                    "utilization_percent": float(parts[4]),
                    "temperature_c": float(parts[5]),
                    "power_draw_w": float(parts[6]) if parts[6] != "[N/A]" else 0,
                })
        return gpus
    except Exception:
        return []


@app.get("/metrics", tags=["Monitoring"])
async def get_metrics():
    """Comprehensive system and model metrics for monitoring dashboard."""
    uptime = time.time() - _start_time
    process = psutil.Process()
    mem_info = process.memory_info()
    
    # System metrics
    cpu_percent = psutil.cpu_percent(interval=0.1)
    virtual_mem = psutil.virtual_memory()
    disk = psutil.disk_usage("/")
    
    # GPU metrics
    gpus = _get_gpu_info()
    
    # Model info
    model_info = {}
    if pipeline:
        model_info = {
            "base_model": pipeline.config.base_model,
            "adapter_path": pipeline.config.adapter_path,
            "model_loaded": pipeline._model_loaded,
            "index_built": pipeline._index_built,
            "index_size": pipeline.vector_store.size if pipeline._index_built else 0,
        }
    
    avg_latency = round(_total_latency / _query_count, 2) if _query_count > 0 else 0
    
    return {
        "server": {
            "uptime_seconds": round(uptime, 1),
            "uptime_human": str(datetime.timedelta(seconds=int(uptime))),
            "timestamp": datetime.datetime.utcnow().isoformat(),
        },
        "system": {
            "cpu_percent": cpu_percent,
            "cpu_count": psutil.cpu_count(),
            "ram_used_gb": round(virtual_mem.used / 1e9, 2),
            "ram_total_gb": round(virtual_mem.total / 1e9, 2),
            "ram_percent": virtual_mem.percent,
            "disk_used_gb": round(disk.used / 1e9, 2),
            "disk_total_gb": round(disk.total / 1e9, 2),
            "disk_percent": round(disk.used / disk.total * 100, 1),
        },
        "process": {
            "pid": process.pid,
            "memory_rss_mb": round(mem_info.rss / 1e6, 1),
            "memory_vms_mb": round(mem_info.vms / 1e6, 1),
            "threads": process.num_threads(),
        },
        "gpus": gpus,
        "model": model_info,
        "requests": {
            "total_queries": _query_count,
            "total_errors": _error_count,
            "error_rate": round(_error_count / max(_query_count, 1) * 100, 1),
            "avg_latency_seconds": avg_latency,
            "total_latency_seconds": round(_total_latency, 2),
        },
        "recent_requests": list(_request_log)[-20:],
    }


@app.get("/metrics/gpu", tags=["Monitoring"])
async def get_gpu_metrics():
    """GPU-specific metrics."""
    return {"gpus": _get_gpu_info()}


@app.get("/metrics/requests", tags=["Monitoring"])
async def get_request_history():
    """Recent request history."""
    return {
        "total": _query_count,
        "errors": _error_count,
        "avg_latency": round(_total_latency / max(_query_count, 1), 2),
        "history": list(_request_log),
    }


# ===== Run =====
if __name__ == "__main__":
    import uvicorn
    
    uvicorn.run(
        "api.app:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info",
    )
