# 🎬 Video Recording Guide: AI Resume Parser Microservices

## 📊 **Performance Metrics (From Logs)**
- **Total Processing Time**: ~104 seconds (1:44 minutes)
- **AI Service Response**: Healthy and responsive
- **Multi-tenant Isolation**: Working perfectly
- **Background Jobs**: Processing efficiently
- **Match Score**: 10.91% for job matching

## 🏗️ **Architecture Overview for Demo**

### Microservices Setup
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Rails App     │    │  AI Extraction   │    │     Ollama      │
│  (Port 3000)    │───▶│   Service        │───▶│   (Port 11434)  │
│                 │    │  (Port 8001)     │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                        │                        │
         ▼                        ▼                        ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   PostgreSQL    │    │      Redis       │    │   Background    │
│  (Port 5432)    │    │   (Port 6379)    │    │     Jobs        │
│                 │    │                  │    │   (Sidekiq)     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## 🎯 **Video Recording Script**

### Part 1: Architecture Overview (2-3 minutes)
```markdown
1. Show project structure
   - Rails application (main business logic)
   - microservices/ directory with AI extraction service
   - Docker Compose setup for orchestration

2. Explain microservices separation
   - Business logic in Rails
   - AI processing in Python FastAPI
   - Local Ollama for private AI processing
   - Multi-tenant architecture with Apartment gem
```

### Part 2: Starting Services (2-3 minutes)
```bash
# Show these commands running

# 1. Start AI microservice
cd microservices
docker-compose up -d

# 2. Verify AI service health
curl http://localhost:8001/health
curl http://localhost:8001/ai-providers

# 3. Start Rails application
cd ..
rails server

# 4. Show tenant access
# Open browser to http://test.localhost:3000
```

### Part 3: Live Demo (5-7 minutes)
```markdown
1. Multi-tenant Login
   - Access http://test.localhost:3000
   - Login with tenant-specific user
   - Show tenant isolation

2. Resume Upload
   - Upload a sample resume (PDF)
   - Show file processing and storage

3. Job Description Creation
   - Create a job description for matching
   - Show structured data entry

4. AI Processing Demo
   - Click "Process with AI"
   - Show real-time status updates
   - Demonstrate ~104 second processing time
   - Show extracted information:
     * Contact details
     * Skills extraction
     * Job matching score
     * Enhancement suggestions

5. Results Display
   - Show structured extracted data
   - Display job match percentage
   - Show AI-generated improvements
```

### Part 4: Technical Deep Dive (3-4 minutes)
```markdown
1. Show logs in real-time
   - Rails processing logs
   - AI service logs
   - Background job execution

2. Database verification
   - Show tenant schema isolation
   - Demonstrate data segregation

3. API communication
   - Show Rails calling AI service
   - Demonstrate error handling
   - Show fallback mechanisms
```

## 🔧 **Pre-Recording Setup Checklist**

### ✅ **Infrastructure**
- [ ] Ollama running with llama3.2:3b model
- [ ] Docker containers up and healthy
- [ ] Rails server running on port 3000
- [ ] AI service responding on port 8001
- [ ] Redis and PostgreSQL operational

### ✅ **Test Data**
- [ ] Development tenant created (subdomain: 'test')
- [ ] Test user account ready
- [ ] Sample resume PDF prepared
- [ ] Sample job description ready
- [ ] Hosts file updated with test.localhost

### ✅ **Browser Setup**
- [ ] Clear browser cache
- [ ] Bookmarks ready for quick navigation
- [ ] Developer tools ready for log viewing
- [ ] Multiple tabs prepared for different views

## 🎬 **Recording Commands Sequence**

### Terminal 1: Start Services
```bash
# Show this running
cd "C:\Users\Yashwanth Sonti\Desktop\Projects\ai-resume-parser\microservices"
docker-compose up -d

# Verify health
curl http://localhost:8001/health
```

### Terminal 2: Rails Application
```bash
cd "C:\Users\Yashwanth Sonti\Desktop\Projects\ai-resume-parser"
rails server
```

### Terminal 3: Monitoring
```bash
# Show live logs
docker logs microservices-ai-extraction-service-1 -f
```

### Terminal 4: Database/Jobs
```bash
# Show background job processing
cd "C:\Users\Yashwanth Sonti\Desktop\Projects\ai-resume-parser"
rails console
# Demonstrate tenant switching and data isolation
```

## 📝 **Key Points to Highlight**

### 🎯 **Architecture Benefits**
- **Separation of Concerns**: Business logic vs AI processing
- **Scalability**: Each service can scale independently
- **Technology Choice**: Rails for web, Python for AI
- **Data Privacy**: Local Ollama, no external AI calls
- **Multi-tenancy**: Complete data isolation

### ⚡ **Performance Highlights**
- **Fast Response**: UI updates in real-time
- **Efficient Processing**: ~104 seconds for complete analysis
- **Background Jobs**: Non-blocking user experience
- **Health Monitoring**: Service availability checks

### 🔒 **Enterprise Features**
- **Multi-tenant Architecture**: Complete customer isolation
- **Local AI Processing**: No data sent to external services
- **Role-based Access**: User and admin roles
- **Audit Trail**: Complete processing history

## 🚀 **Demo Flow for Video**

### 1. Introduction (30 seconds)
"Today I'll demonstrate a microservices-based AI Resume Parser with complete tenant isolation and local AI processing."

### 2. Architecture Tour (2 minutes)
- Show code structure
- Explain microservices separation
- Highlight Docker orchestration

### 3. Live Demo (5 minutes)
- Multi-tenant login
- Resume upload
- AI processing (show full ~104 second cycle)
- Results analysis

### 4. Technical Details (2 minutes)
- Show logs and monitoring
- Demonstrate tenant isolation
- Highlight performance metrics

### 5. Conclusion (30 seconds)
"This architecture provides scalable, secure, and efficient resume processing with complete data privacy."

## 🎥 **Recording Tips**

### 📹 **Video Quality**
- Record in 1080p minimum
- Use clear screen capture software
- Ensure good lighting for any face-to-face segments

### 🎙️ **Audio Quality**
- Use external microphone if possible
- Record in quiet environment
- Test audio levels before starting

### 📱 **Screen Management**
- Use multiple monitors if available
- Prepare browser tabs in advance
- Have terminals ready with commands
- Clear desktop of distractions

## 📋 **Success Criteria**

The video should successfully demonstrate:
- ✅ Microservices architecture working
- ✅ Multi-tenant data isolation
- ✅ Local AI processing (Ollama)
- ✅ Real-time status updates
- ✅ Complete resume processing cycle
- ✅ Job matching functionality
- ✅ Performance metrics (~104s processing)
- ✅ Error handling and fallbacks

## 🔗 **Quick Access URLs**
- **Main App**: http://test.localhost:3000
- **AI Service Health**: http://localhost:8001/health
- **AI Providers**: http://localhost:8001/ai-providers
- **API Gateway**: http://localhost:8080 (if using)

Ready to record your impressive microservices implementation! 🎯🚀