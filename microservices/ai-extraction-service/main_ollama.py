from fastapi import FastAPI, File, UploadFile, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, Dict, Any, List
import tempfile
import os
import uuid
import structlog
from datetime import datetime

from services.pdf_extractor import PDFExtractor
from services.ai_processor import AIProcessor
from services.content_enhancer import ContentEnhancer
from config import settings
from models.extraction_models import ExtractionRequest, ExtractionResponse, EnhancementRequest

# Configure structured logging
structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.UnicodeDecoder(),
        structlog.processors.JSONRenderer()
    ],
    context_class=dict,
    logger_factory=structlog.stdlib.LoggerFactory(),
    wrapper_class=structlog.stdlib.BoundLogger,
    cache_logger_on_first_use=True,
)

logger = structlog.get_logger()

app = FastAPI(
    title="AI Resume Extraction Service - Ollama Edition",
    description="Simple microservice for resume parsing using local Ollama",
    version="1.0.0"
)

# CORS middleware for Rails frontend communication
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://localhost:8080", "*"],  # Rails app and API Gateway
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize services
pdf_extractor = PDFExtractor()
ai_processor = AIProcessor()
content_enhancer = ContentEnhancer()

@app.get("/health")
async def health_check():
    """Health check endpoint for service monitoring"""
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "service": "ai-extraction-service",
        "version": "1.0.0",
        "mode": "ollama-focused"
    }

@app.get("/ai-providers")
async def get_ai_providers():
    """Get available AI providers (Ollama + Basic fallback)"""
    return await ai_processor.get_provider_status()

@app.post("/extract/text")
async def extract_text_from_file(
    file: UploadFile = File(...),
    job_id: Optional[str] = None
):
    """Extract raw text content from uploaded PDF/DOCX file"""
    
    # Generate job ID if not provided
    if not job_id:
        job_id = str(uuid.uuid4())
    
    logger.info("Starting text extraction", job_id=job_id, filename=file.filename)
    
    # Validate file type
    if not file.filename.lower().endswith(('.pdf', '.docx')):
        raise HTTPException(status_code=400, detail="Only PDF and DOCX files are supported")
    
    try:
        # Save uploaded file temporarily
        temp_file = tempfile.NamedTemporaryFile(delete=False, suffix=os.path.splitext(file.filename)[1])
        temp_file.write(await file.read())
        temp_file.close()
        
        # Extract text
        extracted_text = await pdf_extractor.extract_text(temp_file.name)
        
        # Clean up temp file
        os.unlink(temp_file.name)
        
        return {
            "job_id": job_id,
            "filename": file.filename,
            "text": extracted_text["text"],
            "metadata": extracted_text.get("metadata", {}),
            "status": "success",
            "extraction_method": "pdf_extractor"
        }
        
    except Exception as e:
        logger.error("Text extraction failed", job_id=job_id, error=str(e))
        # Clean up temp file if it exists
        try:
            if 'temp_file' in locals():
                os.unlink(temp_file.name)
        except:
            pass
        raise HTTPException(status_code=500, detail=f"Text extraction failed: {str(e)}")

@app.post("/extract/structured")
async def extract_structured_data(
    file: UploadFile = File(...),
    provider: str = "ollama",
    job_id: Optional[str] = None
):
    """Extract structured data from resume using AI (Ollama preferred)"""
    
    # Generate job ID if not provided
    if not job_id:
        job_id = str(uuid.uuid4())
    
    logger.info("Starting structured extraction", job_id=job_id, provider=provider, filename=file.filename)
    
    # Validate file type
    if not file.filename.lower().endswith(('.pdf', '.docx')):
        raise HTTPException(status_code=400, detail="Only PDF and DOCX files are supported")
    
    try:
        # Save uploaded file temporarily
        temp_file = tempfile.NamedTemporaryFile(delete=False, suffix=os.path.splitext(file.filename)[1])
        temp_file.write(await file.read())
        temp_file.close()
        
        # First extract text
        extracted_text = await pdf_extractor.extract_text(temp_file.name)
        text_content = extracted_text["text"]
        
        # Then use AI to structure the data
        structured_data = await ai_processor.process_resume(
            text_content, 
            provider=provider, 
            job_id=job_id
        )
        
        # Clean up temp file
        os.unlink(temp_file.name)
        
        return {
            "job_id": job_id,
            "filename": file.filename,
            "raw_text": text_content,
            "structured_data": structured_data,
            "provider_used": provider,
            "status": "success"
        }
        
    except Exception as e:
        logger.error("Structured extraction failed", job_id=job_id, error=str(e))
        # Clean up temp file if it exists
        try:
            if 'temp_file' in locals():
                os.unlink(temp_file.name)
        except:
            pass
        raise HTTPException(status_code=500, detail=f"Structured extraction failed: {str(e)}")

@app.post("/enhance")
async def enhance_resume_content(
    resume_data: Dict[str, Any],
    job_description: Optional[str] = None,
    provider: str = "ollama",
    job_id: Optional[str] = None
):
    """Enhance resume content for better job matching using Ollama"""
    
    # Generate job ID if not provided
    if not job_id:
        job_id = str(uuid.uuid4())
    
    logger.info("Starting content enhancement", job_id=job_id, provider=provider)
    
    try:
        # Convert resume data to text if it's structured
        if isinstance(resume_data, dict) and 'text' in resume_data:
            resume_text = resume_data['text']
        elif isinstance(resume_data, dict):
            # Convert structured data to readable text
            resume_text = f"""
Name: {resume_data.get('name', 'N/A')}
Email: {resume_data.get('email', 'N/A')}
Phone: {resume_data.get('phone', 'N/A')}

Summary: {resume_data.get('summary', 'N/A')}

Skills: {', '.join(resume_data.get('skills', []))}

Experience: {resume_data.get('experience', 'N/A')}

Education: {resume_data.get('education', 'N/A')}
"""
        else:
            resume_text = str(resume_data)
        
        # Enhance the resume
        enhanced_result = await content_enhancer.enhance_resume(
            resume_text,
            job_description,
            provider=provider,
            job_id=job_id
        )
        
        return {
            "job_id": job_id,
            "original_data": resume_data,
            "enhanced_result": enhanced_result,
            "provider_used": provider,
            "status": "success"
        }
        
    except Exception as e:
        logger.error("Content enhancement failed", job_id=job_id, error=str(e))
        raise HTTPException(status_code=500, detail=f"Content enhancement failed: {str(e)}")

@app.get("/job/{job_id}/status")
async def get_job_status(job_id: str):
    """Get the status of a processing job (placeholder for future async processing)"""
    return {
        "job_id": job_id,
        "status": "completed",  # For now, all jobs are synchronous
        "message": "Job completed successfully"
    }

@app.get("/metrics")
async def get_metrics():
    """Get service metrics for monitoring"""
    try:
        from prometheus_client import generate_latest, CONTENT_TYPE_LATEST
        return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)
    except ImportError:
        return {
            "message": "Prometheus client not installed",
            "basic_metrics": {
                "service": "ai-extraction-service",
                "status": "running",
                "timestamp": datetime.utcnow().isoformat()
            }
        }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8001,
        reload=True,
        log_level="info"
    )