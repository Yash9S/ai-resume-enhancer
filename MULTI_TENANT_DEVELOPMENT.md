# 🏢 Multi-Tenant Development Strategy Guide

## ❌ **What NOT to Do**
- **Don't use `localhost:3000`** - This bypasses tenant routing
- **Don't test without subdomains** - Misses tenant-specific logic
- **Don't upload data to public schema** - Breaks tenant isolation

## ✅ **Recommended Development Approach**

### Option 1: Local Subdomain Development (Recommended)
```bash
# Add to your Windows hosts file: C:\Windows\System32\drivers\etc\hosts
127.0.0.1 test.localhost
127.0.0.1 demo.localhost
127.0.0.1 dev.localhost
127.0.0.1 admin.localhost

# Then access via:
http://test.localhost:3000      # Tenant: test
http://demo.localhost:3000      # Tenant: demo  
http://dev.localhost:3000       # Tenant: dev
http://admin.localhost:3000     # Admin subdomain
```

### Option 2: Use .local Domains
```bash
# Add to hosts file:
127.0.0.1 test.airesumeparser.local
127.0.0.1 demo.airesumeparser.local
127.0.0.1 admin.airesumeparser.local

# Access via:
http://test.airesumeparser.local:3000
http://demo.airesumeparser.local:3000
http://admin.airesumeparser.local:3000
```

### Option 3: Rails Console for Quick Testing
```ruby
# Create test tenant and user via Rails console
rails console

# Create tenant
tenant = Tenant.create!(
  name: "Test Company",
  subdomain: "test",
  status: "active"
)

# Switch to tenant schema
Apartment::Tenant.switch(tenant.subdomain)

# Create test user in public schema
Apartment::Tenant.switch('public')
user = User.create!(
  email: "test@example.com",
  password: "password123",
  password_confirmation: "password123",
  tenant_id: tenant.id
)
```

## 🎯 **Recommended Setup for AI Integration Testing**

### Step 1: Create Development Tenant
```ruby
rails console

# Create development tenant
dev_tenant = Tenant.create!(
  name: "Development Testing",
  subdomain: "dev", 
  status: "active"
)

# Create test user
user = User.create!(
  email: "dev@test.com",
  password: "devpass123",
  password_confirmation: "devpass123",
  tenant_id: dev_tenant.id
)
```

### Step 2: Update Hosts File
```
# Windows: C:\Windows\System32\drivers\etc\hosts
# Add this line:
127.0.0.1 dev.localhost
```

### Step 3: Access Your App
```
http://dev.localhost:3000
```

### Step 4: Login and Test AI
- Login with `dev@test.com` / `devpass123`
- Upload resumes in the proper tenant context
- Test AI processing with your microservices

## 🔧 **Configuration for Multi-Tenant AI Integration**

### Update .env.development
```bash
# AI Service (same for all tenants)
AI_SERVICE_URL=http://localhost:8001

# Redis for background jobs (shared)
REDIS_URL=redis://localhost:6380

# Multi-tenant setup
APARTMENT_EXCLUDED_MODELS=User,Tenant
```

### Tenant-Aware Background Jobs
```ruby
# Update app/jobs/resume_processing_job.rb
class ResumeProcessingJob < ApplicationJob
  queue_as :default
  
  def perform(resume_id, job_description_id = nil, ai_provider = 'ollama')
    resume = Resume.find(resume_id)
    
    # Ensure we're in the correct tenant context
    tenant_subdomain = resume.current_tenant
    
    Apartment::Tenant.switch(tenant_subdomain) do
      # Process resume within tenant context
      ai_service = AiExtractionService.new
      # ... rest of processing
    end
  end
end
```

## 🎯 **Best Practices for AI Integration Testing**

### 1. **Tenant-Specific Testing**
```ruby
# Test in specific tenant context
Apartment::Tenant.switch('dev') do
  resume = Resume.create!(title: "Test Resume", file: file)
  resume.process_with_ai!
end
```

### 2. **Cross-Tenant Data Isolation**
```ruby
# Verify data isolation
Apartment::Tenant.switch('tenant1') do
  Resume.count # Should only show tenant1 resumes
end

Apartment::Tenant.switch('tenant2') do  
  Resume.count # Should only show tenant2 resumes
end
```

### 3. **AI Service Integration**
- AI service is tenant-agnostic (processes any resume)
- Rails app handles tenant routing and data isolation
- Background jobs maintain tenant context

## 📋 **Testing Checklist**

### ✅ **Before AI Integration Testing**
- [ ] Hosts file updated with dev.localhost
- [ ] Development tenant created
- [ ] Test user created with tenant association
- [ ] Can access http://dev.localhost:3000
- [ ] AI microservice running (localhost:8001)

### ✅ **During AI Testing**
- [ ] Upload resumes via proper tenant subdomain
- [ ] Verify tenant isolation (no cross-tenant data leaks)
- [ ] Test AI processing with Ollama
- [ ] Test fallback to basic processing
- [ ] Check background job processing

### ✅ **Verification Steps**
- [ ] Resume data stored in correct tenant schema
- [ ] AI processing works across different tenants
- [ ] No tenant data contamination
- [ ] Proper error handling and logging

## 🚀 **Quick Start Command**

```bash
# 1. Add to hosts file first, then:
cd "C:\Users\Yashwanth Sonti\Desktop\Projects\ai-resume-parser"

# 2. Create tenant (one time)
rails runner "
  tenant = Tenant.find_or_create_by(subdomain: 'dev') do |t|
    t.name = 'Development Testing'
    t.status = 'active'
  end
  
  User.find_or_create_by(email: 'dev@test.com') do |u|
    u.password = 'devpass123'
    u.password_confirmation = 'devpass123'
    u.tenant_id = tenant.id
  end
  
  puts 'Dev tenant ready: http://dev.localhost:3000'
  puts 'Login: dev@test.com / devpass123'
"

# 3. Start Rails
rails server

# 4. Access at http://dev.localhost:3000
```

This approach ensures proper tenant isolation while testing your AI integration! 🎯