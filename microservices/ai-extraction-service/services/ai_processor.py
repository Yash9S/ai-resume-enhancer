import httpx
import structlog
import json
import os
from typing import Dict, Any, Optional, List
from config import settings

logger = structlog.get_logger()

class AIProcessor:
    """Service for AI-powered resume processing using local Ollama"""
    
    def __init__(self):
        self.ollama_url = os.getenv('OLLAMA_BASE_URL', 'http://localhost:11434')
        logger.info(f"AIProcessor initialized with Ollama at: {self.ollama_url}")
    
    async def get_provider_status(self) -> Dict[str, Any]:
        """Check the status of local Ollama and basic fallback"""
        status = {
            "providers": {},
            "recommended": "basic"
        }
        
        # Check Ollama
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(f"{self.ollama_url}/api/tags", timeout=5)
                if response.status_code == 200:
                    models = response.json().get('models', [])
                    status["providers"]["ollama"] = {
                        "available": True,
                        "status": "ready",
                        "cost": "free",
                        "models_count": len(models)
                    }
                    if models:
                        status["recommended"] = "ollama"
                    if status["recommended"] == "basic":
                        status["recommended"] = "ollama"
        except Exception:
            status["providers"]["ollama"] = {
                "available": False,
                "status": "not_running",
                "cost": "free"
            }
        
        # Check Hugging Face
        if settings.HUGGINGFACE_API_KEY:
            status["providers"]["huggingface"] = {
                "available": True,
                "status": "ready",
                "cost": "free"
            }
            if status["recommended"] == "basic":
                status["recommended"] = "huggingface"
        
        # Basic processing is always available
        status["providers"]["basic"] = {
            "available": True,
            "status": "ready",
            "cost": "free"
        }
        
        return status
    
    async def process_resume(self, text: str, provider: str = "auto", job_id: Optional[str] = None) -> Dict[str, Any]:
        """Process resume text with the specified AI provider"""
        
        logger.info("Processing resume with AI", provider=provider, job_id=job_id, text_length=len(text))
        
        if provider == "auto":
            provider = await self._select_best_provider()
        
        try:
            if provider == "openai" and self.openai_client:
                return await self._process_with_openai(text, job_id)
            elif provider == "ollama":
                return await self._process_with_ollama(text, job_id)
            elif provider == "huggingface":
                return await self._process_with_huggingface(text, job_id)
            else:
                return await self._process_with_basic(text, job_id)
                
        except Exception as e:
            logger.error("AI processing failed, falling back to basic", error=str(e), provider=provider)
            return await self._process_with_basic(text, job_id)
    
    async def _select_best_provider(self) -> str:
        """Select the best available provider"""
        status = await self.get_provider_status()
        return status["recommended"]
    
    async def _process_with_openai(self, text: str, job_id: Optional[str]) -> Dict[str, Any]:
        """Process with OpenAI GPT"""
        prompt = self._build_extraction_prompt(text)
        
        try:
            response = self.openai_client.chat.completions.create(
                model="gpt-3.5-turbo",
                messages=[
                    {
                        "role": "system",
                        "content": "You are an expert resume parser. Extract structured information from resumes and return it as valid JSON."
                    },
                    {
                        "role": "user",
                        "content": prompt
                    }
                ],
                max_tokens=1500,
                temperature=0.1
            )
            
            content = response.choices[0].message.content
            return self._parse_ai_response(content, "openai")
            
        except Exception as e:
            logger.error("OpenAI processing failed", error=str(e))
            raise
    
    async def _process_with_ollama(self, text: str, job_id: Optional[str]) -> Dict[str, Any]:
        """Process with local Ollama"""
        prompt = self._build_extraction_prompt(text)
        
        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    f"{settings.OLLAMA_BASE_URL}/api/generate",
                    json={
                        "model": "llama3.2:3b",
                        "prompt": prompt,
                        "stream": False,
                        "options": {
                            "temperature": 0.1,
                            "top_p": 0.9,
                            "num_predict": 800
                        }
                    },
                    timeout=60
                )
                
                if response.status_code == 200:
                    result = response.json()
                    content = result.get("response", "")
                    return self._parse_ai_response(content, "ollama")
                else:
                    raise Exception(f"Ollama request failed: {response.status_code}")
                    
            except Exception as e:
                logger.error("Ollama processing failed", error=str(e))
                raise
    
    async def _process_with_huggingface(self, text: str, job_id: Optional[str]) -> Dict[str, Any]:
        """Process with Hugging Face"""
        # Using a summarization model for basic processing
        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    f"{settings.HUGGINGFACE_BASE_URL}/facebook/bart-large-cnn",
                    headers={"Authorization": f"Bearer {settings.HUGGINGFACE_API_KEY}"},
                    json={
                        "inputs": text[:1000],  # Limit input size
                        "parameters": {
                            "max_length": 500,
                            "min_length": 50
                        }
                    },
                    timeout=30
                )
                
                if response.status_code == 200:
                    result = response.json()
                    summary = result[0].get("summary_text", "")
                    return self._create_structured_from_summary(text, summary, "huggingface")
                else:
                    raise Exception(f"Hugging Face request failed: {response.status_code}")
                    
            except Exception as e:
                logger.error("Hugging Face processing failed", error=str(e))
                raise
    
    async def _process_with_basic(self, text: str, job_id: Optional[str]) -> Dict[str, Any]:
        """Basic text processing without AI"""
        from services.pdf_extractor import PDFExtractor
        
        extractor = PDFExtractor()
        basic_info = extractor.extract_basic_info(text)
        
        return {
            "contact_info": basic_info["contact_info"],
            "skills": basic_info["skills"],
            "education": self._extract_education_basic(text),
            "experience": self._extract_experience_basic(text),
            "summary": text[:300] + "..." if len(text) > 300 else text,
            "provider_used": "basic",
            "extraction_method": "basic_regex"
        }
    
    def _build_extraction_prompt(self, text: str) -> str:
        """Build extraction prompt for AI models"""
        return f"""
Please extract structured information from the following resume text and return it as JSON with these fields:

{{
  "contact_info": {{
    "name": "Full name",
    "email": "email@domain.com",
    "phone": "phone number",
    "location": "city, state"
  }},
  "summary": "Professional summary or objective",
  "experience": [
    {{
      "company": "Company name",
      "position": "Job title",
      "duration": "Start - End dates",
      "description": "Job description and achievements"
    }}
  ],
  "education": [
    {{
      "institution": "School name",
      "degree": "Degree type",
      "field": "Field of study",
      "year": "Graduation year"
    }}
  ],
  "skills": ["List of skills"],
  "certifications": ["List of certifications"]
}}

Resume text:
{text[:2000]}
"""
    
    def _parse_ai_response(self, content: str, provider: str) -> Dict[str, Any]:
        """Parse AI response and extract structured data"""
        try:
            # Try to parse as JSON first
            if content.strip().startswith('{'):
                parsed = json.loads(content)
                parsed["provider_used"] = provider
                parsed["extraction_method"] = "ai_structured"
                return parsed
            else:
                # If not JSON, create structured data from text
                return self._create_structured_from_text(content, provider)
                
        except json.JSONDecodeError:
            # Fallback to text parsing
            return self._create_structured_from_text(content, provider)
    
    def _create_structured_from_text(self, text: str, provider: str) -> Dict[str, Any]:
        """Create structured data from unstructured AI response"""
        return {
            "summary": text[:500],
            "contact_info": {},
            "skills": [],
            "education": [],
            "experience": [],
            "ai_response": text,
            "provider_used": provider,
            "extraction_method": "ai_text_parsing"
        }
    
    def _create_structured_from_summary(self, original_text: str, summary: str, provider: str) -> Dict[str, Any]:
        """Create structured data from AI summary"""
        basic_result = self._process_with_basic(original_text, None)
        basic_result["summary"] = summary
        basic_result["provider_used"] = provider
        basic_result["extraction_method"] = "ai_summary"
        return basic_result
    
    def _extract_education_basic(self, text: str) -> List[Dict[str, str]]:
        """Extract education information using basic patterns"""
        education_keywords = ['university', 'college', 'bachelor', 'master', 'phd', 'degree']
        lines = text.lower().split('\n')
        
        education_entries = []
        for line in lines:
            if any(keyword in line for keyword in education_keywords):
                education_entries.append({
                    "institution": line.strip(),
                    "degree": "",
                    "field": "",
                    "year": ""
                })
        
        return education_entries[:3]  # Limit to 3 entries
    
    def _extract_experience_basic(self, text: str) -> List[Dict[str, str]]:
        """Extract work experience using basic patterns"""
        experience_keywords = ['manager', 'developer', 'engineer', 'analyst', 'director', 'lead']
        lines = text.split('\n')
        
        experience_entries = []
        for line in lines:
            if any(keyword.lower() in line.lower() for keyword in experience_keywords):
                experience_entries.append({
                    "company": "",
                    "position": line.strip(),
                    "duration": "",
                    "description": line.strip()
                })
        
        return experience_entries[:5]  # Limit to 5 entries