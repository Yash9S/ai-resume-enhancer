import structlog
import httpx
import os
from typing import Dict, Any, Optional
from config import settings

logger = structlog.get_logger()

class ContentEnhancer:
    """Service for enhancing resume content using local Ollama - Simple and Reliable"""
    
    def __init__(self):
        self.ollama_url = os.getenv('OLLAMA_BASE_URL', 'http://localhost:11434')
        logger.info(f"ContentEnhancer initialized with Ollama at: {self.ollama_url}")
    
    async def enhance_resume(
        self, 
        resume_content: str, 
        job_description: Optional[str] = None,
        provider: str = "ollama",
        job_id: Optional[str] = None
    ) -> Dict[str, Any]:
        """Enhance resume content using local Ollama (with basic fallback)"""
        
        logger.info("Starting content enhancement", job_id=job_id, provider=provider)
        
        try:
            if provider == "ollama":
                return await self._enhance_with_ollama(resume_content, job_description, job_id)
            else:
                # For any other provider, use basic enhancement
                return await self._enhance_with_basic(resume_content, job_description, job_id)
                
        except Exception as e:
            logger.error("Enhancement failed, falling back to basic", error=str(e), provider=provider)
            return await self._enhance_with_basic(resume_content, job_description, job_id)
    
    async def _check_ollama_availability(self) -> bool:
        """Check if Ollama is available and has models"""
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(f"{self.ollama_url}/api/tags", timeout=5)
                if response.status_code == 200:
                    models = response.json().get('models', [])
                    return len(models) > 0
        except Exception as e:
            logger.warning(f"Ollama availability check failed: {e}")
        return False
    
    async def _get_available_models(self) -> list:
        """Get list of available Ollama models"""
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(f"{self.ollama_url}/api/tags", timeout=5)
                if response.status_code == 200:
                    data = response.json()
                    return [model['name'] for model in data.get('models', [])]
        except Exception as e:
            logger.warning(f"Failed to get Ollama models: {e}")
        return []
    
    async def _enhance_with_ollama(
        self, 
        resume_content: str, 
        job_description: Optional[str], 
        job_id: Optional[str]
    ) -> Dict[str, Any]:
        """Enhance content using local Ollama"""
        
        # Check if Ollama is available
        if not await self._check_ollama_availability():
            logger.warning("Ollama not available, falling back to basic enhancement")
            return await self._enhance_with_basic(resume_content, job_description, job_id)
        
        # Get available models
        available_models = await self._get_available_models()
        if not available_models:
            logger.warning("No Ollama models available, using basic enhancement")
            return await self._enhance_with_basic(resume_content, job_description, job_id)
        
        # Preferred models in order of preference
        preferred_models = ["llama3.2", "llama2", "mistral", "phi3", "gemma"]
        model_to_use = None
        
        # Find the first available preferred model
        for model in preferred_models:
            if any(model in available_model for available_model in available_models):
                model_to_use = next(m for m in available_models if model in m)
                break
        
        # If no preferred model found, use the first available model
        if not model_to_use:
            model_to_use = available_models[0]
            
        logger.info(f"Using Ollama model: {model_to_use}")
        
        prompt = self._build_enhancement_prompt(resume_content, job_description)
        
        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    f"{self.ollama_url}/api/generate",
                    json={
                        "model": model_to_use,
                        "prompt": prompt,
                        "stream": False,
                        "options": {
                            "temperature": 0.3,
                            "top_p": 0.9,
                            "num_predict": 800
                        }
                    },
                    timeout=120  # 2 minutes for local processing
                )
                
                if response.status_code == 200:
                    result = response.json()
                    ai_response = result.get("response", "")
                    
                    if not ai_response:
                        logger.warning("Empty response from Ollama, using basic enhancement")
                        return await self._enhance_with_basic(resume_content, job_description, job_id)
                    
                    enhanced_result = self._parse_enhancement_response(ai_response, resume_content, job_description, f"ollama-{model_to_use}")
                    enhanced_result["model_used"] = model_to_use
                    return enhanced_result
                else:
                    logger.error(f"Ollama request failed with status: {response.status_code}")
                    return await self._enhance_with_basic(resume_content, job_description, job_id)
                    
            except Exception as e:
                logger.error("Ollama enhancement failed", error=str(e))
                return await self._enhance_with_basic(resume_content, job_description, job_id)
    
    async def _enhance_with_basic(
        self, 
        resume_content: str, 
        job_description: Optional[str], 
        job_id: Optional[str]
    ) -> Dict[str, Any]:
        """Basic enhancement without AI"""
        
        suggestions = [
            "Use more action verbs (led, managed, developed, implemented)",
            "Add quantifiable achievements with numbers and percentages",
            "Include relevant keywords from the job description",
            "Strengthen your professional summary with specific accomplishments",
            "Highlight technical skills that match the job requirements"
        ]
        
        # Add job-specific suggestions if job description provided
        if job_description:
            jd_keywords = self._extract_keywords(job_description.lower())
            resume_keywords = self._extract_keywords(resume_content.lower())
            
            missing_keywords = [kw for kw in jd_keywords if kw not in resume_keywords]
            if missing_keywords:
                suggestions.append(f"Consider including these relevant keywords: {', '.join(missing_keywords[:5])}")
        
        match_score = self.calculate_match_score(resume_content, job_description) if job_description else 0
        
        return {
            "enhanced_content": resume_content,  # No changes in basic mode
            "suggestions": suggestions,
            "match_score": match_score,
            "provider_used": "basic",
            "enhancement_method": "basic_suggestions"
        }
    
    def calculate_match_score(self, resume_content: str, job_description: Optional[str]) -> float:
        """Calculate how well the resume matches the job description"""
        
        if not job_description:
            return 0.0
        
        # Simple keyword-based matching
        jd_keywords = set(self._extract_keywords(job_description.lower()))
        resume_keywords = set(self._extract_keywords(resume_content.lower()))
        
        if not jd_keywords:
            return 0.0
        
        matches = len(jd_keywords.intersection(resume_keywords))
        total_keywords = len(jd_keywords)
        
        score = (matches / total_keywords) * 100
        return round(score, 2)
    
    def _build_enhancement_prompt(self, resume_content: str, job_description: Optional[str]) -> str:
        """Build enhancement prompt for AI models"""
        
        base_prompt = f"""
Please analyze the following resume and provide specific suggestions for improvement:

Resume Content:
{resume_content[:1500]}

Please provide:
1. 3-5 specific suggestions for improving this resume
2. Ways to better highlight relevant experience and skills
3. Suggestions for strengthening the professional summary
4. Tips for better keyword optimization

Focus on actionable, practical advice.
"""
        
        if job_description:
            base_prompt += f"""
Target Job Description:
{job_description[:800]}

Additionally, suggest how to better align the resume with this specific job:
- Which skills should be emphasized more
- What experience should be highlighted
- How to incorporate relevant keywords naturally
"""
        
        return base_prompt
    
    def _parse_enhancement_response(
        self, 
        ai_response: str, 
        original_content: str, 
        job_description: Optional[str],
        provider: str
    ) -> Dict[str, Any]:
        """Parse AI enhancement response into structured format"""
        
        # Extract suggestions from AI response
        suggestions = self._extract_suggestions_from_text(ai_response)
        
        # Calculate match score if job description provided
        match_score = 0
        if job_description:
            match_score = self.calculate_match_score(original_content, job_description)
        
        return {
            "enhanced_content": original_content,  # AI provides suggestions, not rewritten content
            "suggestions": suggestions,
            "match_score": match_score,
            "ai_feedback": ai_response,
            "provider_used": provider,
            "enhancement_method": "ai_suggestions"
        }
    
    def _extract_suggestions_from_text(self, text: str) -> list:
        """Extract actionable suggestions from AI response text"""
        suggestions = []
        lines = text.split('\n')
        
        for line in lines:
            cleaned_line = line.strip()
            
            # Look for numbered lists, bullet points, or suggestion patterns
            if any(pattern in cleaned_line.lower() for pattern in ['suggest', 'recommend', 'consider', 'improve']):
                # Remove common prefixes
                cleaned_line = cleaned_line.lstrip('•-*123456789. ')
                if len(cleaned_line) > 20:  # Only meaningful suggestions
                    suggestions.append(cleaned_line)
            
            elif cleaned_line.startswith(('•', '-', '*')) or cleaned_line.match(r'^\d+\.'):
                cleaned_line = cleaned_line.lstrip('•-*123456789. ')
                if len(cleaned_line) > 15:
                    suggestions.append(cleaned_line)
        
        # Fallback: if no clear suggestions found, use the first few sentences
        if not suggestions and text:
            sentences = text.split('. ')
            suggestions = [s.strip() + '.' for s in sentences[:3] if len(s.strip()) > 20]
        
        return suggestions[:7]  # Limit to 7 suggestions
    
    def _extract_keywords(self, text: str) -> list:
        """Extract relevant keywords from text"""
        import re
        
        # Remove common stop words
        stop_words = {
            'the', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of', 'with',
            'by', 'from', 'up', 'about', 'into', 'through', 'during', 'before',
            'after', 'above', 'below', 'between', 'among', 'through', 'during',
            'before', 'after', 'above', 'below', 'up', 'down', 'out', 'off', 'over',
            'under', 'again', 'further', 'then', 'once', 'here', 'there', 'when',
            'where', 'why', 'how', 'all', 'any', 'both', 'each', 'few', 'more',
            'most', 'other', 'some', 'such', 'no', 'nor', 'not', 'only', 'own',
            'same', 'so', 'than', 'too', 'very', 'can', 'will', 'just', 'should'
        }
        
        # Extract words (2+ characters, alphanumeric)
        words = re.findall(r'\b[a-zA-Z][a-zA-Z0-9]*\b', text.lower())
        
        # Filter out stop words and short words
        keywords = [word for word in words if len(word) >= 3 and word not in stop_words]
        
        # Return unique keywords
        return list(set(keywords))