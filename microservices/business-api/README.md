# AI Resume Parser - Business Logic API

This is the Rails API-only service that handles:
- User authentication and management
- Multi-tenancy with Apartment gem
- Resume and job description CRUD operations
- Database management
- Service orchestration

## Configuration

Convert your existing Rails app to API-only mode:

1. **Update Application Configuration**:
```ruby
# config/application.rb
config.api_only = true
```

2. **Update Controllers**:
- Inherit from `ActionController::API` instead of `ActionController::Base`
- Remove view-related code
- Return JSON responses

3. **Remove Unnecessary Gems**:
- Remove view-related gems (sass, turbo, stimulus)
- Keep API-essential gems (rack-cors, etc.)

4. **Update Routes**:
- Focus on API routes with versioning
- Remove non-API routes

## API Endpoints

### Authentication
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/logout`
- `POST /api/v1/auth/refresh`

### Users
- `GET /api/v1/users/profile`
- `PUT /api/v1/users/profile`

### Tenants (Admin only)
- `GET /api/v1/tenants`
- `POST /api/v1/tenants`
- `PUT /api/v1/tenants/:id`
- `DELETE /api/v1/tenants/:id`

### Resumes
- `GET /api/v1/resumes`
- `POST /api/v1/resumes`
- `GET /api/v1/resumes/:id`
- `PUT /api/v1/resumes/:id`
- `DELETE /api/v1/resumes/:id`
- `POST /api/v1/resumes/:id/process`

### Job Descriptions
- `GET /api/v1/job_descriptions`
- `POST /api/v1/job_descriptions`
- `GET /api/v1/job_descriptions/:id`
- `PUT /api/v1/job_descriptions/:id`
- `DELETE /api/v1/job_descriptions/:id`

## Service Communication

This service communicates with:
- **AI Extraction Service**: For resume processing
- **Frontend**: Provides API responses
- **Database**: PostgreSQL with multi-tenancy

## Migration Steps

1. Copy your existing Rails app to this directory
2. Follow the configuration changes above
3. Update the controllers to be API-only
4. Update the job processors to call the AI service
5. Test the API endpoints

## Environment Variables

```
DATABASE_URL=postgresql://...
REDIS_URL=redis://localhost:6379
AI_EXTRACTION_SERVICE_URL=http://localhost:8001
JWT_SECRET=your_jwt_secret
RAILS_ENV=development
```