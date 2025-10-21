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
    title="AI Resume Extraction Service",
    description="Microservice for AI-powered resume parsing and enhancement",
    version="1.0.0"
)

# CORS middleware for frontend communication
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
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
        "version": "1.0.0"
    }

@app.get("/ai-providers")
async def get_ai_providers():
    """Get available AI providers and their status"""
    return await ai_processor.get_provider_status()

@app.post("/extract/text", response_model=Dict[str, Any])
async def extract_text_from_file(
    file: UploadFile = File(...),
    job_id: Optional[str] = None
):
    """Extract text content from uploaded PDF/DOCX file"""
    
    # Generate job ID if not provided
    if not job_id:
        job_id = str(uuid.uuid4())
    
    logger.info("Starting text extraction", job_id=job_id, filename=file.filename)
    
    try:
        # Validate file type
        if not file.content_type in ['application/pdf', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document']:
            raise HTTPException(status_code=400, detail="Unsupported file type")
        
        # Save uploaded file temporarily
        with tempfile.NamedTemporaryFile(delete=False, suffix=os.path.splitext(file.filename)[1]) as tmp_file:
            content = await file.read()
            tmp_file.write(content)
            tmp_file_path = tmp_file.name
        
        try:
            # Extract text based on file type
            if file.content_type == 'application/pdf':
                extracted_text = await pdf_extractor.extract_from_pdf(tmp_file_path)
            else:
                extracted_text = await pdf_extractor.extract_from_docx(tmp_file_path)
            
            response = {
                "job_id": job_id,
                "success": True,
                "extracted_text": extracted_text,
                "file_info": {
                    "filename": file.filename,
                    "size": file.size,
                    "content_type": file.content_type
                },
                "extraction_method": "text_only",
                "timestamp": datetime.utcnow().isoformat()
            }
            
            logger.info("Text extraction completed", job_id=job_id, text_length=len(extracted_text))
            return response
            
        finally:
            # Clean up temporary file
            os.unlink(tmp_file_path)
            
    except Exception as e:
        logger.error("Text extraction failed", job_id=job_id, error=str(e))
        raise HTTPException(status_code=500, detail=f"Extraction failed: {str(e)}")

@app.post("/extract/structured", response_model=ExtractionResponse)
async def extract_structured_data(
    file: UploadFile = File(...),
    job_id: Optional[str] = None,
    ai_provider: Optional[str] = "auto"
):
    """Extract structured resume data using AI processing"""
    
    if not job_id:
        job_id = str(uuid.uuid4())
    
    logger.info("Starting structured extraction", job_id=job_id, filename=file.filename, ai_provider=ai_provider)
    
    try:
        # First extract text
        with tempfile.NamedTemporaryFile(delete=False, suffix=os.path.splitext(file.filename)[1]) as tmp_file:
            content = await file.read()
            tmp_file.write(content)
            tmp_file_path = tmp_file.name
        
        try:
            # Extract text
            if file.content_type == 'application/pdf':
                extracted_text = await pdf_extractor.extract_from_pdf(tmp_file_path)
            else:
                extracted_text = await pdf_extractor.extract_from_docx(tmp_file_path)
            
            # Process with AI
            structured_data = await ai_processor.process_resume(
                text=extracted_text,
                provider=ai_provider,
                job_id=job_id
            )
            
            response = ExtractionResponse(
                job_id=job_id,
                success=True,
                original_text=extracted_text,
                structured_data=structured_data,
                file_info={
                    "filename": file.filename,
                    "size": file.size,
                    "content_type": file.content_type
                },
                ai_provider=structured_data.get("provider_used", ai_provider),
                timestamp=datetime.utcnow().isoformat()
            )
            
            logger.info("Structured extraction completed", job_id=job_id)
            return response
            
        finally:
            os.unlink(tmp_file_path)
            
    except Exception as e:
        logger.error("Structured extraction failed", job_id=job_id, error=str(e))
        raise HTTPException(status_code=500, detail=f"Extraction failed: {str(e)}")

@app.post("/enhance")
async def enhance_content(request: EnhancementRequest):
    """Enhance resume content for specific job descriptions"""
    
    logger.info("Starting content enhancement", job_id=request.job_id)
    
    try:
        enhancement_result = await content_enhancer.enhance_resume(
            resume_content=request.resume_content,
            job_description=request.job_description,
            provider=request.ai_provider,
            job_id=request.job_id
        )
        
        response = {
            "job_id": request.job_id,
            "success": True,
            "enhanced_content": enhancement_result["enhanced_content"],
            "suggestions": enhancement_result["suggestions"],
            "match_score": enhancement_result.get("match_score", 0),
            "ai_provider": enhancement_result.get("provider_used", request.ai_provider),
            "timestamp": datetime.utcnow().isoformat()
        }
        
        logger.info("Content enhancement completed", job_id=request.job_id)
        return response
        
    except Exception as e:
        logger.error("Content enhancement failed", job_id=request.job_id, error=str(e))
        raise HTTPException(status_code=500, detail=f"Enhancement failed: {str(e)}")

@app.get("/job/{job_id}/status")
async def get_job_status(job_id: str):
    """Get the status of a processing job"""
    # This would typically check Redis or a job queue
    # For now, return a simple response
    return {
        "job_id": job_id,
        "status": "completed",  # In reality, check actual job status
        "timestamp": datetime.utcnow().isoformat()
    }

@app.get("/metrics")
async def get_metrics():
    """Prometheus metrics endpoint"""
    from prometheus_client import generate_latest, CONTENT_TYPE_LATEST
    from fastapi import Response
    
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8001,
        reload=True,
        log_config={
            "version": 1,
            "disable_existing_loggers": False,
            "formatters": {
                "default": {
                    "format": "%(asctime)s - %(name)s - %(levelname)s - %(message)s",
                },
            },
            "handlers": {
                "default": {
                    "formatter": "default",
                    "class": "logging.StreamHandler",
                    "stream": "ext://sys.stdout",
                },
            },
            "root": {
                "level": "INFO",
                "handlers": ["default"],
            },
        }
    )