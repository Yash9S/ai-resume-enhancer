# 🚀 **Video Guide 2: Microservices Implementation in AI Resume Parser**

## 📋 **Overview**
This guide explains the hybrid monolith-to-microservices architecture with service communication, API versioning, and containerization.

---

## 🎯 **Video Recording Focus Points**

### **1. Architecture Overview** (2-3 minutes)
- Current hybrid approach: Rails + External Services
- Service communication patterns
- Docker containerization strategy

### **2. File Structure Overview** (3-4 minutes)
```
Key Files to Show:
├── microservices/
│   ├── docker-compose.yml                    # Service orchestration
│   ├── ai-extraction-service/               # Python FastAPI service
│   ├── business-api/                        # Rails API-only service
│   └── frontend/                           # React frontend service
├── app/controllers/api/                     # API versioning
├── config/routes.rb                         # API routing
└── app/services/microservice_client.rb      # Service communication
```

---

## 📁 **File #1: Service Orchestration**

### **📄 File: `microservices/docker-compose.yml`**

**Show this exact code in your video:**

```yaml
version: '3.8'

services:
  # PostgreSQL Database (Shared)
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: ai_resume_parser_development
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    networks:
      - ai-resume-network

  # Redis (Shared Cache & Queue)
  redis:
    image: redis:7
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    networks:
      - ai-resume-network

  # AI Extraction Service (Python FastAPI)
  ai-extraction-service:
    build:
      context: ./ai-extraction-service
      dockerfile: Dockerfile
    ports:
      - "8001:8001"
    environment:
      - REDIS_URL=redis://redis:6379/0
      - DATABASE_URL=postgresql://postgres:postgres@postgres:5432/ai_resume_parser_development
    depends_on:
      - redis
      - postgres
    volumes:
      - ./ai-extraction-service:/app
      - /app/venv  # Exclude virtual environment
    networks:
      - ai-resume-network
    command: ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8001", "--reload"]

  # Business Logic API (Rails)
  business-api:
    build:
      context: ..
      dockerfile: microservices/business-api/Dockerfile
    ports:
      - "3001:3001"
    environment:
      - RAILS_ENV=development
      - DATABASE_URL=postgresql://postgres:postgres@postgres:5432/ai_resume_parser_development
      - REDIS_URL=redis://redis:6379/0
      - AI_SERVICE_URL=http://ai-extraction-service:8001
    depends_on:
      - postgres
      - redis
      - ai-extraction-service
    volumes:
      - ..:/rails
    networks:
      - ai-resume-network
    command: ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "3001"]

  # Frontend Service (React/Next.js)
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=development
      - NEXT_PUBLIC_API_URL=http://localhost:3001/api/v1
      - NEXT_PUBLIC_WS_URL=ws://localhost:3001/cable
    depends_on:
      - business-api
    volumes:
      - ./frontend:/app
      - /app/node_modules
    networks:
      - ai-resume-network
    command: ["npm", "run", "dev"]

  # API Gateway (Nginx)
  api-gateway:
    build:
      context: ./api-gateway
      dockerfile: Dockerfile
    ports:
      - "8080:80"
    depends_on:
      - business-api
      - ai-extraction-service
      - frontend
    volumes:
      - ./api-gateway/nginx.conf:/etc/nginx/nginx.conf
    networks:
      - ai-resume-network

volumes:
  postgres_data:
  redis_data:

networks:
  ai-resume-network:
    driver: bridge
```

**🎥 Explain in Video:**
1. **Line 4-16**: Shared PostgreSQL database with initialization
2. **Line 18-25**: Redis for caching and job queues
3. **Line 27-43**: Python AI service configuration
4. **Line 45-62**: Rails business logic API
5. **Line 64-79**: React frontend service
6. **Line 81-92**: Nginx API gateway

---

## 📁 **File #2: AI Extraction Service**

### **📄 File: `microservices/ai-extraction-service/main.py`**

**Show this exact code in your video:**

```python
from fastapi import FastAPI, HTTPException, UploadFile, File, BackgroundTasks
from pydantic import BaseModel
from typing import Optional, List, Dict, Any
import asyncio
import aioredis
import asyncpg
import PyPDF2
import docx
import openai
import json
import logging
from datetime import datetime
import uuid

# Initialize FastAPI app
app = FastAPI(
    title="AI Resume Extraction Service",
    description="Microservice for AI-powered resume parsing and enhancement",
    version="1.0.0"
)

# Database and Redis connections
redis_pool = None
db_pool = None

# Pydantic models for API contracts
class ResumeUpload(BaseModel):
    tenant_id: str
    user_id: int
    title: str
    file_type: str  # 'pdf' or 'docx'

class ExtractionResult(BaseModel):
    resume_id: str
    extracted_text: str
    parsed_data: Dict[str, Any]
    skills: List[str]
    experience_years: Optional[int]
    education: List[Dict[str, str]]
    contact_info: Dict[str, str]
    processing_time: float

class EnhancementRequest(BaseModel):
    resume_id: str
    job_description: Optional[str] = None
    enhancement_type: str = "general"  # 'general', 'job_match', 'skills_boost'

# Startup and shutdown events
@app.on_event("startup")
async def startup_event():
    global redis_pool, db_pool
    
    # Initialize Redis connection
    redis_pool = aioredis.ConnectionPool.from_url(
        "redis://redis:6379/0", 
        decode_responses=True
    )
    
    # Initialize PostgreSQL connection
    db_pool = await asyncpg.create_pool(
        "postgresql://postgres:postgres@postgres:5432/ai_resume_parser_development",
        min_size=5,
        max_size=20
    )
    
    logging.info("AI Extraction Service started successfully")

@app.on_event("shutdown")
async def shutdown_event():
    if redis_pool:
        await redis_pool.disconnect()
    if db_pool:
        await db_pool.close()

# Health check endpoint
@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "service": "ai-extraction-service",
        "timestamp": datetime.utcnow().isoformat(),
        "version": "1.0.0"
    }

# Resume extraction endpoint
@app.post("/api/extract", response_model=ExtractionResult)
async def extract_resume(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    tenant_id: str = None,
    user_id: int = None,
    title: str = None
):
    try:
        # Generate unique resume ID
        resume_id = str(uuid.uuid4())
        
        # Read file content
        file_content = await file.read()
        
        # Extract text based on file type
        if file.content_type == "application/pdf":
            extracted_text = extract_pdf_text(file_content)
        elif file.content_type in ["application/vnd.openxmlformats-officedocument.wordprocessingml.document", "application/msword"]:
            extracted_text = extract_docx_text(file_content)
        else:
            raise HTTPException(status_code=400, detail="Unsupported file type")
        
        # Process with AI
        start_time = datetime.utcnow()
        parsed_data = await process_with_ai(extracted_text)
        processing_time = (datetime.utcnow() - start_time).total_seconds()
        
        # Store results in database
        background_tasks.add_task(
            store_extraction_result,
            resume_id, tenant_id, user_id, title, extracted_text, parsed_data
        )
        
        # Return extraction result
        return ExtractionResult(
            resume_id=resume_id,
            extracted_text=extracted_text,
            parsed_data=parsed_data,
            skills=parsed_data.get("skills", []),
            experience_years=parsed_data.get("experience_years"),
            education=parsed_data.get("education", []),
            contact_info=parsed_data.get("contact_info", {}),
            processing_time=processing_time
        )
        
    except Exception as e:
        logging.error(f"Extraction error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Extraction failed: {str(e)}")

# Resume enhancement endpoint
@app.post("/api/enhance")
async def enhance_resume(request: EnhancementRequest):
    try:
        # Retrieve original resume data
        async with db_pool.acquire() as connection:
            resume_data = await connection.fetchrow(
                f"SELECT extracted_text, parsed_data FROM {request.tenant_id}.resumes WHERE id = $1",
                request.resume_id
            )
        
        if not resume_data:
            raise HTTPException(status_code=404, detail="Resume not found")
        
        # Enhance with AI based on type
        enhanced_content = await enhance_with_ai(
            resume_data['extracted_text'],
            request.job_description,
            request.enhancement_type
        )
        
        # Update database
        async with db_pool.acquire() as connection:
            await connection.execute(
                f"UPDATE {request.tenant_id}.resumes SET enhanced_content = $1, updated_at = $2 WHERE id = $3",
                enhanced_content,
                datetime.utcnow(),
                request.resume_id
            )
        
        return {
            "resume_id": request.resume_id,
            "enhanced_content": enhanced_content,
            "enhancement_type": request.enhancement_type,
            "processed_at": datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        logging.error(f"Enhancement error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Enhancement failed: {str(e)}")

# Helper functions
def extract_pdf_text(file_content: bytes) -> str:
    """Extract text from PDF file"""
    import io
    pdf_reader = PyPDF2.PdfReader(io.BytesIO(file_content))
    text = ""
    for page in pdf_reader.pages:
        text += page.extract_text() + "\n"
    return text.strip()

def extract_docx_text(file_content: bytes) -> str:
    """Extract text from DOCX file"""
    import io
    doc = docx.Document(io.BytesIO(file_content))
    text = ""
    for paragraph in doc.paragraphs:
        text += paragraph.text + "\n"
    return text.strip()

async def process_with_ai(text: str) -> Dict[str, Any]:
    """Process resume text with AI to extract structured data"""
    
    prompt = f"""
    Extract the following information from this resume text:
    
    Text: {text}
    
    Return a JSON object with:
    - skills: array of technical skills
    - experience_years: number of years of experience
    - education: array of education entries with degree, school, year
    - contact_info: object with email, phone, location
    - job_titles: array of previous job titles
    - companies: array of previous companies
    
    Return only valid JSON.
    """
    
    try:
        # Use OpenAI API (or local model)
        response = await asyncio.to_thread(
            openai.ChatCompletion.create,
            model="gpt-3.5-turbo",
            messages=[{"role": "user", "content": prompt}],
            max_tokens=1500
        )
        
        result = json.loads(response.choices[0].message.content)
        return result
        
    except Exception as e:
        logging.error(f"AI processing error: {str(e)}")
        return {
            "skills": [],
            "experience_years": None,
            "education": [],
            "contact_info": {},
            "job_titles": [],
            "companies": []
        }

async def enhance_with_ai(original_text: str, job_description: str, enhancement_type: str) -> str:
    """Enhance resume content with AI"""
    
    prompts = {
        "general": "Improve this resume to make it more professional and impactful:",
        "job_match": f"Optimize this resume for this job description:\n\nJob: {job_description}\n\nResume:",
        "skills_boost": "Enhance the skills and achievements section of this resume:"
    }
    
    prompt = f"{prompts.get(enhancement_type, prompts['general'])}\n\n{original_text}"
    
    try:
        response = await asyncio.to_thread(
            openai.ChatCompletion.create,
            model="gpt-3.5-turbo",
            messages=[{"role": "user", "content": prompt}],
            max_tokens=2000
        )
        
        return response.choices[0].message.content
        
    except Exception as e:
        logging.error(f"AI enhancement error: {str(e)}")
        return original_text

async def store_extraction_result(resume_id: str, tenant_id: str, user_id: int, title: str, extracted_text: str, parsed_data: Dict):
    """Store extraction results in the database"""
    try:
        async with db_pool.acquire() as connection:
            await connection.execute(f"""
                INSERT INTO {tenant_id}.resumes (id, user_id, title, extracted_content, extracted_data, created_at, updated_at)
                VALUES ($1, $2, $3, $4, $5, $6, $7)
            """, resume_id, user_id, title, extracted_text, json.dumps(parsed_data), datetime.utcnow(), datetime.utcnow())
            
        logging.info(f"Stored extraction result for resume {resume_id}")
        
    except Exception as e:
        logging.error(f"Database storage error: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
```

**🎥 Explain in Video:**
1. **Line 16-21**: FastAPI service initialization
2. **Line 27-36**: Pydantic models for API contracts
3. **Line 45-63**: Service startup with database connections
4. **Line 72-118**: Resume extraction endpoint with AI processing
5. **Line 121-151**: Resume enhancement endpoint
6. **Line 154-200**: Helper functions for file processing and AI integration

---

## 📁 **File #3: Rails API Controller (Business Logic)**

### **📄 File: `microservices/business-api/api_controller_example.rb`**

**Show this exact code in your video:**

```ruby
# Example API-only controller for the Business Logic service

class Api::V1::ResumesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_resume, only: [:show, :update, :destroy, :process_resume]

  # GET /api/v1/resumes
  def index
    @resumes = current_user.resumes.includes(:resume_processings)
                          .page(params[:page])
                          .per(params[:per_page] || 10)
                          .order(created_at: :desc)
    
    render json: {
      resumes: @resumes.map(&method(:serialize_resume)),
      pagination: {
        current_page: @resumes.current_page,
        total_pages: @resumes.total_pages,
        total_count: @resumes.total_count
      }
    }
  end

  # GET /api/v1/resumes/:id
  def show
    render json: {
      resume: serialize_resume(@resume),
      processings: @resume.resume_processings.recent.map(&method(:serialize_processing))
    }
  end

  # POST /api/v1/resumes
  def create
    @resume = current_user.resumes.build(resume_params)
    
    if @resume.save
      render json: { resume: serialize_resume(@resume) }, status: :created
    else
      render json: { errors: @resume.errors }, status: :unprocessable_entity
    end
  end

  # PUT /api/v1/resumes/:id
  def update
    if @resume.update(resume_params)
      render json: { resume: serialize_resume(@resume) }
    else
      render json: { errors: @resume.errors }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/resumes/:id
  def destroy
    @resume.destroy
    head :no_content
  end

  # POST /api/v1/resumes/:id/process
  def process_resume
    job_description_id = params[:job_description_id]
    job_description = job_description_id.present? ? 
                     current_user.job_descriptions.find(job_description_id) : nil
    
    # Instead of ProcessResumeJob, call AI service directly
    ProcessResumeWithAIServiceJob.perform_later(@resume, job_description, current_user)
    
    @resume.update(status: :processing)
    
    render json: { 
      message: 'Resume processing started',
      resume: serialize_resume(@resume) 
    }
  end

  private

  def set_resume
    @resume = current_user.resumes.find(params[:id])
  end

  def resume_params
    params.require(:resume).permit(:title, :file)
  end

  def serialize_resume(resume)
    {
      id: resume.id,
      title: resume.title,
      filename: resume.file.attached? ? resume.file.filename : nil,
      file_size: resume.file.attached? ? resume.file.byte_size : nil,
      status: resume.status,
      extracted_content: resume.extracted_content,
      enhanced_content: resume.enhanced_content,
      extracted_data: resume.extracted_data,
      created_at: resume.created_at,
      updated_at: resume.updated_at,
      file_url: resume.file.attached? ? rails_blob_path(resume.file) : nil
    }
  end

  def serialize_processing(processing)
    {
      id: processing.id,
      processing_type: processing.processing_type,
      status: processing.status,
      match_score: processing.match_score,
      result: processing.result,
      started_at: processing.started_at,
      completed_at: processing.completed_at,
      job_description: processing.job_description&.title
    }
  end
end
```

**🎥 Explain in Video:**
1. **Line 4-5**: Authentication and authorization
2. **Line 7-22**: Paginated resume listing with serialization
3. **Line 31-39**: Resume creation with validation
4. **Line 54-66**: AI service integration for processing
5. **Line 76-89**: JSON serialization methods

---

## 📁 **File #4: Service Communication Client**

### **📄 File: `app/services/microservice_client.rb`**

**Show this exact code in your video:**

```ruby
class MicroserviceClient
  include HTTParty
  
  def initialize(service_name)
    @service_name = service_name
    @base_url = Rails.application.config.microservice_urls[service_name]
    @timeout = 30
  end
  
  def post(endpoint, data, tenant_context = nil)
    response = self.class.post(
      "#{@base_url}#{endpoint}",
      headers: build_headers(tenant_context),
      body: data.to_json,
      timeout: @timeout
    )
    
    handle_response(response)
  rescue Net::TimeoutError => e
    Rails.logger.error "Microservice timeout: #{@service_name} - #{e.message}"
    fallback_response(503, 'Service timeout')
  rescue Errno::ECONNREFUSED => e
    Rails.logger.error "Microservice connection refused: #{@service_name} - #{e.message}"
    fallback_response(503, 'Service unavailable')
  rescue StandardError => e
    Rails.logger.error "Microservice error: #{@service_name} - #{e.message}"
    fallback_response(500, 'Internal service error')
  end
  
  def get(endpoint, tenant_context = nil)
    response = self.class.get(
      "#{@base_url}#{endpoint}",
      headers: build_headers(tenant_context),
      timeout: @timeout
    )
    
    handle_response(response)
  rescue Net::TimeoutError => e
    Rails.logger.error "Microservice timeout: #{@service_name} - #{e.message}"
    fallback_response(503, 'Service timeout')
  rescue StandardError => e
    Rails.logger.error "Microservice error: #{@service_name} - #{e.message}"
    fallback_response(500, 'Internal service error')
  end
  
  def upload_file(endpoint, file, additional_data = {}, tenant_context = nil)
    response = self.class.post(
      "#{@base_url}#{endpoint}",
      headers: build_headers(tenant_context, multipart: true),
      body: {
        file: file,
        **additional_data
      },
      timeout: 60 # Longer timeout for file uploads
    )
    
    handle_response(response)
  rescue Net::TimeoutError => e
    Rails.logger.error "File upload timeout: #{@service_name} - #{e.message}"
    fallback_response(503, 'Upload timeout')
  rescue StandardError => e
    Rails.logger.error "File upload error: #{@service_name} - #{e.message}"
    fallback_response(500, 'Upload failed')
  end
  
  private
  
  def build_headers(tenant_context, multipart: false)
    headers = {
      'User-Agent' => 'AIResumeParser/1.0',
      'Accept' => 'application/json'
    }
    
    unless multipart
      headers['Content-Type'] = 'application/json'
    end
    
    if tenant_context
      headers['X-Tenant-ID'] = tenant_context[:tenant_id]
      headers['X-User-ID'] = tenant_context[:user_id].to_s
      
      if tenant_context[:jwt_token]
        headers['Authorization'] = "Bearer #{tenant_context[:jwt_token]}"
      end
    end
    
    headers
  end
  
  def handle_response(response)
    case response.code
    when 200..299
      OpenStruct.new(
        success?: true,
        data: response.parsed_response,
        status: response.code,
        headers: response.headers
      )
    when 400..499
      OpenStruct.new(
        success?: false,
        error: response.parsed_response&.dig('error') || 'Client error',
        status: response.code,
        data: response.parsed_response
      )
    when 500..599
      OpenStruct.new(
        success?: false,
        error: 'Server error',
        status: response.code,
        data: response.parsed_response
      )
    else
      fallback_response(response.code, 'Unknown error')
    end
  end
  
  def fallback_response(status = 503, message = 'Service unavailable')
    OpenStruct.new(
      success?: false,
      error: message,
      status: status,
      data: nil
    )
  end
end

# Usage examples in services
class ResumeProcessingService
  def self.process_with_ai_service(resume, tenant_context)
    client = MicroserviceClient.new(:ai_extraction)
    
    # Upload file to AI service
    response = client.upload_file(
      '/api/extract',
      resume.file.blob,
      {
        tenant_id: tenant_context[:tenant_id],
        user_id: tenant_context[:user_id],
        title: resume.title
      },
      tenant_context
    )
    
    if response.success?
      # Update resume with AI results
      resume.update!(
        extracted_content: response.data['extracted_text'],
        extracted_data: response.data['parsed_data']
      )
      
      Rails.logger.info "AI processing completed for resume #{resume.id}"
      response.data
    else
      Rails.logger.error "AI processing failed: #{response.error}"
      raise StandardError, "AI processing failed: #{response.error}"
    end
  end
  
  def self.enhance_resume(resume, job_description, tenant_context)
    client = MicroserviceClient.new(:ai_extraction)
    
    response = client.post(
      '/api/enhance',
      {
        resume_id: resume.id,
        job_description: job_description&.content,
        enhancement_type: 'job_match'
      },
      tenant_context
    )
    
    if response.success?
      resume.update!(enhanced_content: response.data['enhanced_content'])
      response.data
    else
      raise StandardError, "Enhancement failed: #{response.error}"
    end
  end
end
```

**🎥 Explain in Video:**
1. **Line 4-8**: Service client initialization with configuration
2. **Line 10-27**: POST requests with error handling and fallbacks
3. **Line 45-60**: File upload handling with extended timeout
4. **Line 64-82**: Header building with tenant context and JWT
5. **Line 84-108**: Response handling and status code management
6. **Line 120-161**: Usage examples in service classes

---

## 📁 **File #5: API Routes Configuration**

### **📄 File: `config/routes.rb` (Microservices section)**

**Show this exact code in your video:**

```ruby
Rails.application.routes.draw do
  # Health check for load balancers
  get '/health', to: 'health#check'
  
  # API versioning for microservices compatibility
  namespace :api do
    # Version 1 - Current monolith compatibility
    namespace :v1 do
      resources :resumes, only: [:index, :show, :create, :update, :destroy] do
        member do
          post :process           # Process with AI
          post :enhance          # Enhance content
          get :analysis          # Get AI analysis
          get :download          # Download processed resume
        end
        
        collection do
          get :stats             # Resume statistics
          post :bulk_upload      # Bulk resume processing
        end
      end
      
      resources :job_descriptions, only: [:index, :show, :create, :update, :destroy] do
        member do
          post :match_resumes    # Match against resumes
        end
      end
      
      resources :users, only: [:show, :update] do
        member do
          get :dashboard         # User dashboard data
          get :activity          # User activity log
        end
      end
      
      resources :tenants, only: [:show, :create, :update] do
        member do
          get :stats             # Tenant statistics
          post :switch           # Switch tenant context
        end
      end
    end
    
    # Version 2 - Future microservice endpoints
    namespace :v2 do
      # These will proxy to microservices
      resources :resumes, only: [:index, :show, :create, :update, :destroy] do
        member do
          post :ai_process       # Proxy to AI service
          post :ai_enhance       # Proxy to AI service
          get :ai_analysis       # Proxy to AI service
        end
      end
      
      # AI service endpoints (proxied)
      namespace :ai do
        post 'extract', to: 'ai_proxy#extract'
        post 'enhance', to: 'ai_proxy#enhance'
        get 'health', to: 'ai_proxy#health'
      end
      
      # Business logic endpoints
      namespace :business do
        resources :tenants, only: [:index, :show, :create, :update, :destroy]
        resources :users, only: [:index, :show, :create, :update, :destroy]
        resources :analytics, only: [:index, :show]
      end
    end
  end
  
  # Traditional Rails routes (for hybrid mode)
  root 'dashboard#index'
  devise_for :users
  
  resources :dashboard, only: [:index] do
    collection do
      get :react_index       # React-enabled dashboard
    end
  end
  
  resources :resumes do
    member do
      post :process_resume
      get :view_processed
    end
  end
  
  resources :job_descriptions
  
  # Admin routes
  namespace :admin do
    resources :tenants
    resources :users
    get 'dashboard', to: 'dashboard#index'
  end
end
```

**🎥 Explain in Video:**
1. **Line 5-8**: API versioning strategy for migration
2. **Line 9-35**: V1 API (current monolith endpoints)
3. **Line 41-60**: V2 API (future microservice endpoints)
4. **Line 52-57**: AI service proxy endpoints
5. **Line 59-64**: Business logic service endpoints

---

## 🔄 **Service Communication Flow Demonstration**

### **Show this flow in your terminal during video:**

```bash
# 1. Start all microservices
cd microservices
docker-compose up

# Expected output:
# ✓ postgres running on port 5432
# ✓ redis running on port 6379  
# ✓ ai-extraction-service running on port 8001
# ✓ business-api running on port 3001
# ✓ frontend running on port 3000
# ✓ api-gateway running on port 8080

# 2. Test service health checks
curl http://localhost:8001/health  # AI service
curl http://localhost:3001/health  # Business API
curl http://localhost:3000/health  # Frontend

# 3. Test service communication
curl -X POST http://localhost:8001/api/extract \
  -F "file=@sample_resume.pdf" \
  -F "tenant_id=tenant_demo" \
  -F "user_id=1" \
  -F "title=Software Engineer Resume"

# 4. Check logs for service interaction
docker-compose logs -f ai-extraction-service
docker-compose logs -f business-api
```

### **Rails Console Demonstration:**

```ruby
# Rails console microservice testing
rails console

# 1. Create microservice client
client = MicroserviceClient.new(:ai_extraction)

# 2. Test tenant context
tenant_context = {
  tenant_id: 'tenant_demo',
  user_id: 1,
  jwt_token: 'example_jwt_token'
}

# 3. Test health check
response = client.get('/health')
puts response.success?  # => true
puts response.data      # => {"status"=>"healthy", "service"=>"ai-extraction-service"}

# 4. Test AI processing
resume = Resume.first
result = ResumeProcessingService.process_with_ai_service(resume, tenant_context)
puts result['skills']           # => ["Ruby", "Rails", "JavaScript"]
puts result['experience_years'] # => 5
```

---

## 🎯 **Key Points to Emphasize in Video**

### **1. Hybrid Architecture Benefits**
- **Gradual Migration**: Move services incrementally
- **Technology Diversity**: Python for AI, Rails for business logic
- **Independent Scaling**: Scale AI processing separately
- **Fault Tolerance**: Service isolation prevents cascading failures

### **2. Service Communication Patterns**
```
Frontend (React) 
    ↓ HTTP/REST
API Gateway (Nginx)
    ↓ Route based on path
Business API (Rails) ←→ AI Service (Python)
    ↓ Database calls     ↓ File processing
PostgreSQL            Redis Queue
```

### **3. API Versioning Strategy**
- **V1**: Current monolith compatibility
- **V2**: Future microservice-native endpoints
- **Gradual Migration**: Support both versions during transition

### **4. Container Orchestration**
- **Shared Database**: PostgreSQL for all services
- **Shared Cache**: Redis for sessions and job queues
- **Service Discovery**: Docker networking with service names
- **Volume Mounts**: Development code reloading

### **5. Error Handling & Resilience**
- **Circuit Breaker Pattern**: Fallback responses
- **Timeout Handling**: Prevent hanging requests
- **Graceful Degradation**: Continue operation when services fail
- **Comprehensive Logging**: Track service interactions

---

## 📝 **Video Script Outline**

1. **Introduction** (30s)
   - "Today I'll explain our microservices implementation strategy"

2. **Architecture Overview** (2m)
   - Show docker-compose.yml file
   - Explain service responsibilities and communication

3. **AI Service Deep Dive** (3m)
   - Show Python FastAPI service code
   - Explain AI processing endpoints and async handling

4. **Business API Integration** (2m)
   - Show Rails API controller
   - Explain service-to-service communication

5. **Service Communication Client** (2m)
   - Show MicroserviceClient class
   - Explain error handling and fallback strategies

6. **Live Demo** (2m)
   - Start services with docker-compose
   - Test API endpoints and service interaction

7. **Summary** (30s)
   - Benefits of hybrid approach and migration strategy

**Total Duration: ~10 minutes**