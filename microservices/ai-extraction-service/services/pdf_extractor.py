import PyPDF2
import docx
import structlog
from typing import Optional

logger = structlog.get_logger()

class PDFExtractor:
    """Service for extracting text from PDF and DOCX files"""
    
    async def extract_from_pdf(self, file_path: str) -> str:
        """Extract text from PDF file"""
        try:
            with open(file_path, 'rb') as file:
                pdf_reader = PyPDF2.PdfReader(file)
                text = ""
                
                for page_num in range(len(pdf_reader.pages)):
                    page = pdf_reader.pages[page_num]
                    text += page.extract_text() + "\n"
                
                if not text.strip():
                    return "Unable to extract text from PDF - file may be image-based"
                
                logger.info(f"Extracted {len(text)} characters from PDF")
                return text.strip()
                
        except Exception as e:
            logger.error(f"PDF extraction failed: {str(e)}")
            raise Exception(f"PDF processing failed: {str(e)}")
    
    async def extract_from_docx(self, file_path: str) -> str:
        """Extract text from DOCX file"""
        try:
            doc = docx.Document(file_path)
            text = []
            
            for paragraph in doc.paragraphs:
                if paragraph.text.strip():
                    text.append(paragraph.text)
            
            extracted_text = "\n".join(text)
            
            if not extracted_text.strip():
                return "Unable to extract text from DOCX file"
            
            logger.info(f"Extracted {len(extracted_text)} characters from DOCX")
            return extracted_text.strip()
            
        except Exception as e:
            logger.error(f"DOCX extraction failed: {str(e)}")
            raise Exception(f"DOCX processing failed: {str(e)}")
    
    def extract_basic_info(self, text: str) -> dict:
        """Extract basic information using regex patterns"""
        import re
        
        # Email extraction
        email_pattern = r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'
        emails = re.findall(email_pattern, text)
        
        # Phone extraction
        phone_pattern = r'\b(?:\+?1[-.\s]?)?\(?[0-9]{3}\)?[-.\s]?[0-9]{3}[-.\s]?[0-9]{4}\b'
        phones = re.findall(phone_pattern, text)
        
        # Skills extraction (basic keyword matching)
        tech_skills = [
            'Python', 'Java', 'JavaScript', 'Ruby', 'Rails', 'React', 'Node.js',
            'SQL', 'HTML', 'CSS', 'Git', 'AWS', 'Azure', 'Docker', 'Kubernetes',
            'Machine Learning', 'AI', 'Data Science', 'Project Management'
        ]
        
        found_skills = []
        text_lower = text.lower()
        for skill in tech_skills:
            if skill.lower() in text_lower:
                found_skills.append(skill)
        
        return {
            "contact_info": {
                "emails": emails[:2],  # Limit to 2 emails
                "phones": phones[:2]   # Limit to 2 phone numbers
            },
            "skills": found_skills,
            "text_length": len(text),
            "extraction_method": "basic_regex"
        }