from pydantic import BaseModel
from typing import Optional, Dict, Any, List
from datetime import datetime

class ExtractionRequest(BaseModel):
    job_id: Optional[str] = None
    ai_provider: Optional[str] = "auto"
    
class ExtractionResponse(BaseModel):
    job_id: str
    success: bool
    original_text: str
    structured_data: Dict[str, Any]
    file_info: Dict[str, Any]
    ai_provider: str
    timestamp: str
    error: Optional[str] = None

class EnhancementRequest(BaseModel):
    job_id: Optional[str] = None
    resume_content: str
    job_description: Optional[str] = None
    ai_provider: Optional[str] = "auto"

class EnhancementResponse(BaseModel):
    job_id: str
    success: bool
    enhanced_content: str
    suggestions: List[str]
    match_score: float
    ai_provider: str
    timestamp: str
    error: Optional[str] = None

class JobStatus(BaseModel):
    job_id: str
    status: str  # pending, processing, completed, failed
    progress: Optional[int] = None
    result: Optional[Dict[str, Any]] = None
    error: Optional[str] = None
    created_at: datetime
    updated_at: datetime

class ContactInfo(BaseModel):
    name: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None
    location: Optional[str] = None

class WorkExperience(BaseModel):
    company: Optional[str] = None
    position: Optional[str] = None
    duration: Optional[str] = None
    description: Optional[str] = None

class Education(BaseModel):
    institution: Optional[str] = None
    degree: Optional[str] = None
    field: Optional[str] = None
    year: Optional[str] = None

class StructuredResumeData(BaseModel):
    contact_info: ContactInfo
    summary: Optional[str] = None
    experience: List[WorkExperience] = []
    education: List[Education] = []
    skills: List[str] = []
    certifications: List[str] = []
    provider_used: str
    extraction_method: str