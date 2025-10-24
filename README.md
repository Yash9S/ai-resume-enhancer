# AI Resume Parser - Rails Application with Microfrontends

## Project Overview
This is a Ruby on Rails application for AI-powered resume parsing and enhancement with modern microfrontend architecture. The application allows users to upload resumes, match them against job descriptions, and enhance content using AI.

## Architecture
- **Framework**: Ruby on Rails 8.0.3 (MVC Architecture)
- **Database**: MySQL 8.0 with multi-tenancy via Apartment gem
- **Authentication**: Devise with role-based access (Users, Admins)
- **File Storage**: Active Storage for resume uploads
- **AI Integration**: Ollama local AI for resume parsing
- **Background Jobs**: Sidekiq with Redis for async processing
- **Microfrontends**: Single SPA + SystemJS ImportMap with React components
- **Containerization**: Docker Compose for all services

## Core Features
- Resume upload (PDF/DOCX)
- Job description matching with AI analysis
- AI-powered content extraction and enhancement
- Interactive microfrontend interfaces
- Real-time processing status tracking
- Multi-tenant architecture
- Resume export/download
- Role-based authentication

## 🚀 Complete Setup Guide

### Prerequisites
- **Docker & Docker Compose** (v20.10 or higher)
- **Git** for version control
- **Web Browser** (Chrome, Firefox, Edge)

### 1. Initial Setup

```bash
# Clone the repository
git clone https://github.com/Yash9S/ai-resume-enhancer.git
cd ai-resume-parser

# Copy environment files (if needed)
cp .env.example .env  # Edit database credentials if needed
```

### 2. Start All Services with Docker

```bash
# Start database and Redis services
docker-compose up -d database redis

# Wait for database to be healthy (about 30 seconds)
docker-compose logs database  # Check for "ready for connections"

# Build and start Rails application
docker-compose up -d web

# Start microfrontend services
cd microfrontends
docker-compose up -d widget-service
cd ..
```

### 3. Database Setup

```bash
# Run database setup (run this inside the Rails container)
docker-compose exec web bash -c "
  bundle exec rails db:create
  bundle exec rails db:migrate
  bundle exec rails db:seed
"

# Or run migrations locally if Rails is installed
bundle exec rails db:create db:migrate db:seed
```

### 4. Start Sidekiq Background Jobs

```bash
# Option A: Using Docker (recommended)
docker-compose exec web bundle exec sidekiq

# Option B: Local Sidekiq (if Rails installed locally)
# In a separate terminal:
bundle exec sidekiq

# Option C: Windows batch script
# Double-click: start_sidekiq.bat
```

### 5. Verify All Services

Check that all services are running:

```bash
# Check Docker services
docker-compose ps

# Should show:
# - database (mysql:8.0) - healthy - port 3306
# - redis (redis:7-alpine) - healthy - port 6379  
# - web (rails app) - up - port 3000

# Check microfrontend services
cd microfrontends && docker-compose ps

# Should show:
# - widget-service - up - port 4005
```

### 6. Access the Application

- **Main Application**: http://localhost:3000
- **Microfrontend Service**: http://localhost:4005
- **Login**: Use default admin credentials or sign up

## 📊 Service Architecture

### Port Configuration
- **Rails Application**: Port 3000
- **MySQL Database**: Port 3306
- **Redis**: Port 6379
- **Widget Service (Microfrontends)**: Port 4005
- **Sidekiq Web UI**: Port 4567 (if enabled)

### Docker Services
```yaml
# Main services (docker-compose.yml)
- database: MySQL 8.0 with health checks
- redis: Redis 7 Alpine for Sidekiq
- web: Rails application with Puma server

# Microfrontend services (microfrontends/docker-compose.yml)
- widget-service: Express.js serving React microfrontends
```

## 🔧 Development Commands

### Starting Development Environment

```bash
# Full stack startup (recommended)
./bin/dev  # If available, or use commands below

# Manual startup:
# Terminal 1: Start database services
docker-compose up database redis

# Terminal 2: Start Rails server
rails server

# Terminal 3: Start Sidekiq
bundle exec sidekiq

# Terminal 4: Start microfrontend service
cd microfrontends
docker-compose up widget-service
```

### Database Management

```bash
# Create databases
rails db:create

# Run migrations
rails db:migrate

# Seed data (creates tenant databases and sample data)
rails db:seed

# Reset database (⚠️ DESTRUCTIVE)
rails db:drop db:create db:migrate db:seed

# Create new tenant
rails console
> Tenant.create!(name: "New Company", subdomain: "newco", schema_name: "newco", status: "active")
```

### Background Job Management

```bash
# Start Sidekiq worker
bundle exec sidekiq

# Check job status
rails console
> Sidekiq::Queue.new.size  # Check queue size
> Sidekiq::Workers.new.size  # Check active workers

# Clear failed jobs
> require 'sidekiq/api'
> Sidekiq::RetrySet.new.clear
> Sidekiq::DeadSet.new.clear
```

### Microfrontend Development

```bash
# Check microfrontend health
curl http://localhost:4005/health

# Test microfrontend endpoint
curl http://localhost:4005/job-descriptions-widget.js

# Rebuild microfrontend service
cd microfrontends
docker-compose down widget-service
docker-compose up --build widget-service
```

## 🧪 Testing & Debugging

### Service Health Checks

```bash
# Check all Docker services
docker-compose ps

# Check database connection
docker-compose exec database mysql -u ai_resume_parser -p -e "SHOW DATABASES;"

# Check Redis connection
docker-compose exec redis redis-cli ping

# Check Rails logs
docker-compose logs web

# Check Sidekiq logs
docker-compose logs web | grep sidekiq
```

### Common Issues & Solutions

#### 1. Database Connection Issues
```bash
# Check if database is healthy
docker-compose ps database

# Restart database service
docker-compose restart database

# Check database logs
docker-compose logs database
```

#### 2. Apartment Gem Multi-tenancy Issues
```bash
# Check tenant databases exist
docker-compose exec database mysql -u ai_resume_parser -p -e "SHOW DATABASES;"

# Should show: test, acme, techstart, etc.

# Check apartment configuration
rails console
> Apartment.tenant_names
> Apartment.current  # Should return current tenant
```

#### 3. Sidekiq Jobs Not Processing
```bash
# Check Sidekiq is running
ps aux | grep sidekiq

# Check Redis connection
redis-cli ping

# Check job queue
rails console
> Sidekiq::Queue.new.size
> ResumeProcessingJob.perform_later(resume_id: 1)  # Test job
```

#### 4. Microfrontend Not Loading
```bash
# Check widget service is running
curl http://localhost:4005/health

# Check SystemJS ImportMap in browser console
# Should see: "Loading Job Descriptions Microfrontend..."

# Check for CORS issues
curl -H "Origin: http://localhost:3000" http://localhost:4005/job-descriptions-widget.js
```

## 🏗️ Architecture Details

### Multi-tenancy (Apartment Gem)
- **Main Database**: `ai_resume_parser_development` (contains Users, Tenants)
- **Tenant Databases**: `test`, `acme`, `techstart` (contain tenant-specific data)
- **Elevator**: Custom subdomain-based tenant switching
- **Default Tenant**: `test` for development

### Microfrontend Architecture
- **Single SPA**: Orchestrates microfrontend lifecycle
- **SystemJS ImportMap**: Module resolution for dependencies
- **React Components**: Interactive UI components
- **Data Flow**: Rails → HTML data attributes → React props

### Background Processing
- **Sidekiq**: Async job processing with Redis
- **ResumeProcessingJob**: AI extraction and analysis
- **Retry Logic**: Automatic retries with exponential backoff
- **Monitoring**: Job status tracking and error handling

## 📈 Production Deployment

### Environment Variables
```bash
# .env file
RAILS_ENV=production
DATABASE_URL=mysql2://user:pass@host:3306/db
REDIS_URL=redis://host:6379/0
SECRET_KEY_BASE=your_secret_key
OLLAMA_BASE_URL=http://ollama:11434
```

### Docker Production
```bash
# Build production images
docker-compose -f docker-compose.prod.yml build

# Deploy with production settings
docker-compose -f docker-compose.prod.yml up -d

# Run production migrations
docker-compose -f docker-compose.prod.yml exec web rails db:migrate
```

## 🤝 Contributing

1. **Fork the repository**
2. **Create feature branch**: `git checkout -b feature/amazing-feature`
3. **Commit changes**: `git commit -m 'Add amazing feature'`
4. **Push to branch**: `git push origin feature/amazing-feature`
5. **Open Pull Request**

### Development Guidelines
- Follow Rails conventions and MVC patterns
- Write comprehensive tests for all functionality
- Use semantic commits and proper documentation
- Maintain separation of concerns with service objects
- Test microfrontends in multiple browsers

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Issues**: GitHub Issues for bug reports
- **Documentation**: Check this README and code comments
- **Community**: Discussions tab for questions

---

**Status**: ✅ Fully Functional - Multi-tenant Rails app with AI processing and microfrontends

## 🏗️ Architecture Overview

### Microservices Setup
- **Rails Application**: Business logic, multi-tenancy, user management (Port 3000)
- **AI Extraction Service**: Python FastAPI service for resume processing (Port 8001)
- **Local Ollama**: Private AI processing with llama3.2:3b model (Port 11434)
- **Docker Orchestration**: Complete containerized deployment with health checks

### Performance Metrics
- **Processing Time**: ~104 seconds average for complete resume analysis
- **AI Response**: Real-time status updates with background job processing
- **Multi-tenant Isolation**: Complete data segregation per organization
- **Job Match Accuracy**: AI-powered scoring with enhancement suggestions

## 🚀 Key Features

- 🏢 **Multi-tenant Architecture**: Complete data isolation per organization
- 🤖 **Local AI Processing**: No external AI services, complete privacy with Ollama
- ⚡ **Background Jobs**: Non-blocking resume processing with Sidekiq
- 📊 **Job Matching**: AI-powered resume-to-job matching with percentage scores
- 🔒 **Enterprise Security**: Role-based access, tenant isolation, audit trails
- 📱 **Real-time Updates**: Live processing status and results via AJAX
- 📄 **Multi-format Support**: PDF and DOCX resume uploads
- ✨ **Content Enhancement**: AI-driven suggestions for resume improvement

## 🤖 AI Service Options

| Service | Cost | Quality | Setup | Recommendation |
|---------|------|---------|-------|----------------|
| **Hugging Face** | 🟢 FREE | Good | Easy | Best for development |
| **Ollama (Local)** | 🟢 FREE | Good | Medium | Best for privacy |
| **OpenAI GPT** | 🟡 ~$0.005/resume | Excellent | Easy | Best for production |
| **Basic Processing** | 🟢 FREE | Basic | None | Always available |

> 💡 The app automatically chooses the best available service based on your configuration!

## 🛠️ Technology Stack

- **Framework**: Ruby on Rails 8.0
- **Database**: PostgreSQL 16
- **Background Jobs**: Sidekiq with Redis
- **Authentication**: Devise with role-based authorization
- **File Storage**: Active Storage
- **AI Integration**: OpenAI API, Hugging Face, Ollama (local AI)
- **Frontend**: Bootstrap 5, Turbo, Stimulus
- **Containerization**: Docker & Docker Compose
- **Testing**: RSpec, FactoryBot, Faker

## 📋 Prerequisites

- Docker Desktop
- Git
- Text editor/IDE

## 🚀 Quick Start with Free Local AI

### 1. Clone and Start the Application
```bash
git clone https://github.com/your-username/ai-resume-parser.git
cd ai-resume-parser

# Start the application
docker-compose up -d
```

### 2. Set Up Free Local AI (Ollama)
```bash
# Start Ollama for free AI processing
docker run -d --name ollama-ai -v ollama:/root/.ollama -p 11434:11434 --restart unless-stopped ollama/ollama

# Download a free AI model (one-time setup)
docker exec ollama-ai ollama pull llama3.2:3b

# Test the AI integration
ruby scripts/test_ollama.rb
```

### 3. Access Your Application
- **Web Interface**: http://localhost:3000
- **Admin Account**: admin@airesume.com / password
- **AI Processing**: 100% free with Ollama!
```

### 2. Run the Setup Script

**For Linux/macOS:**
```bash
chmod +x setup-docker.sh
./setup-docker.sh
```

**For Windows:**
```cmd
setup-docker.bat
```

**Manual Docker Setup:**
```bash
# Copy environment file
cp .env.example .env

# Build and start services
docker-compose build
docker-compose up -d database redis

# Wait for database to start (about 15 seconds)
# Setup database
docker-compose run --rm web rails db:setup

# Start all services
docker-compose up
```

### 3. Access the Application
- **Web App**: http://localhost:3000
- **Admin Dashboard**: http://localhost:3000/sidekiq (admin only)
- **PostgreSQL**: localhost:5432
- **Redis**: localhost:6379

### 4. Default Login Credentials
- **Admin**: admin@airesume.com / password123
- **User**: user@example.com / password123

## � Local Development (Without Docker)

### Prerequisites
- Ruby 3.4.6+
- Rails 8.0.3+
- PostgreSQL 16+
- Redis 7+
- Node.js (for asset compilation)

### Installation Steps

### Installation Steps

```bash
# Install dependencies
bundle install

# Setup PostgreSQL database
createuser -s ai_resume_parser
createdb ai_resume_parser_development
createdb ai_resume_parser_test

# Run migrations and seed
rails db:migrate db:seed

# Start Redis (in another terminal)
redis-server

# Start Sidekiq (in another terminal)
bundle exec sidekiq

# Start Rails server
rails server
```

## 🐳 Docker Commands

### Development
```bash
# Start all services
docker-compose up

# Run in background
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down

# Clean up everything
docker-compose down -v --remove-orphans
```

### Database Operations
```bash
# Access Rails console
docker-compose run --rm web rails console

# Run migrations
docker-compose run --rm web rails db:migrate

# Reset database
docker-compose run --rm web rails db:drop db:create db:migrate db:seed

# Access PostgreSQL
docker-compose exec database psql -U ai_resume_parser -d ai_resume_parser_development
```

### Debugging
```bash
# Access container shell
docker-compose run --rm web bash

# Check container logs
docker-compose logs web
docker-compose logs database
docker-compose logs redis
```

## 🔑 Environment Variables

Copy `.env.example` to `.env` and configure:

### OpenAI API (Recommended)
1. Create account at [OpenAI Platform](https://platform.openai.com/)
2. Generate API key from the API Keys section
3. Add to `.env` file: `OPENAI_API_KEY=your_key_here`

### Hugging Face API (Alternative)
1. Create account at [Hugging Face](https://huggingface.co/)
2. Generate access token from Settings → Tokens
3. Add to `.env` file: `HUGGINGFACE_API_KEY=your_key_here`

### Local Development (Fallback)
The application includes basic text extraction that works without API keys, though with limited functionality.

## 📖 Usage Guide

### 1. User Registration
- Visit `/users/sign_up` to create an account
- Choose role: User (default) or Admin

### 2. Upload Resume
- Navigate to "Upload Resume" from the dashboard
- Select PDF or DOCX file (max 10MB)
- Add a descriptive title

### 3. Process Resume
- Click "Process Resume" to extract content using AI
- Processing happens in the background
- View results once processing completes

### 4. Job Description Matching
- Add job descriptions via "Job Descriptions" menu
- Process resumes against specific job descriptions
- Get match scores and enhancement suggestions

### 5. Edit & Enhance Content
- Use the built-in editor to refine extracted content
- Apply AI suggestions for improvements
- Save multiple versions

### 6. Export Results
- Download enhanced resumes in multiple formats
- Options: PDF, TXT, or original format

## 🏗️ Project Structure

```
app/
├── controllers/           # Application controllers
│   ├── dashboard_controller.rb
│   ├── resumes_controller.rb
│   └── job_descriptions_controller.rb
├── models/               # Data models
│   ├── user.rb
│   ├── resume.rb
│   ├── job_description.rb
│   └── resume_processing.rb
├── services/             # Business logic services
│   └── resume_parsing_service.rb
├── jobs/                 # Background job classes
│   └── process_resume_job.rb
└── views/               # View templates
    ├── dashboard/
    ├── resumes/
    └── layouts/
```

## 🧪 Testing

```bash
# Install test dependencies
bundle install

# Set up test database
rails db:test:prepare

# Run the full test suite
bundle exec rspec

# Run specific tests
bundle exec rspec spec/models/
bundle exec rspec spec/controllers/
bundle exec rspec spec/services/
```

## 🚀 Deployment

### Heroku Deployment
```bash
# Create Heroku app
heroku create your-app-name

# Set environment variables
heroku config:set OPENAI_API_KEY=your_key
heroku config:set RAILS_MASTER_KEY=your_master_key

# Deploy
git push heroku main
heroku run rails db:migrate
```

### Production Configuration
- Switch to PostgreSQL for production database
- Configure environment variables
- Set up background job processing (Redis + Sidekiq recommended)
- Configure file storage (AWS S3, Google Cloud, etc.)

## 🔒 Security Features

- CSRF protection enabled
- SQL injection prevention via ActiveRecord
- File upload validation and sanitization
- User authentication and authorization
- Secure API key management
- Content Security Policy headers

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 Development Notes

### Adding New AI Providers
Extend `ResumeParsingService` to support additional AI services by implementing new parsing methods following the existing pattern.

### Customizing Resume Templates
Resume export templates can be customized in the `ResumesController#generate_pdf_content` method or by integrating PDF generation libraries.

### Background Processing
Resume processing uses Active Job. For production, consider using Redis with Sidekiq for better performance and reliability.

## 🐛 Troubleshooting

### Common Issues

**Database Connection Error**
```bash
rails db:create
rails db:migrate
```

**Missing API Keys**
- Check `.env` file exists and contains valid API keys
- Restart Rails server after adding environment variables

**File Upload Issues**
- Verify Active Storage is properly configured
- Check file size limits (default: 10MB)
- Ensure supported file formats (PDF, DOCX)

**Background Job Not Processing**
- Ensure Active Job adapter is properly configured
- Check Rails logs for error details

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- OpenAI for providing GPT API
- Hugging Face for machine learning models
- Ruby on Rails community for excellent documentation
- Bootstrap team for UI components

---

For questions or support, please open an issue on GitHub or contact the development team.
