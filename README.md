# 🤖 AI Resume Parser - Microservices Architecture

A production-ready Ruby on Rails application with microservices architecture for AI-powered resume parsing and job matching.

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
