import os
from typing import List

class Settings:
    # API Keys
    OPENAI_API_KEY: str = os.getenv("OPENAI_API_KEY", "")
    HUGGINGFACE_API_KEY: str = os.getenv("HUGGINGFACE_API_KEY", "")
    
    # Service URLs
    OLLAMA_BASE_URL: str = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
    HUGGINGFACE_BASE_URL: str = os.getenv("HUGGINGFACE_BASE_URL", "https://api-inference.huggingface.co/models")
    REDIS_URL: str = os.getenv("REDIS_URL", "redis://localhost:6379")
    
    # CORS
    ALLOWED_ORIGINS: List[str] = [
        "http://localhost:3000",  # Frontend
        "http://localhost:3001",  # Business API
        "http://localhost:8080",  # API Gateway
        "http://127.0.0.1:3000",
        "http://127.0.0.1:3001",
        "http://127.0.0.1:8080"
    ]
    
    # File Processing
    MAX_FILE_SIZE: int = 10 * 1024 * 1024  # 10MB
    ALLOWED_FILE_TYPES: List[str] = [
        "application/pdf",
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    ]
    
    # AI Processing
    DEFAULT_AI_PROVIDER: str = "auto"
    AI_TIMEOUT: int = 60  # seconds
    MAX_TEXT_LENGTH: int = 10000  # characters
    
    # Logging
    LOG_LEVEL: str = os.getenv("LOG_LEVEL", "INFO")
    
    # Service Info
    SERVICE_NAME: str = "ai-extraction-service"
    SERVICE_VERSION: str = "1.0.0"
    SERVICE_PORT: int = int(os.getenv("PORT", "8001"))

settings = Settings()