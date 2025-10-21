# 🏢 Apartment Gem Multi-Tenancy Integration Guide
## Complete Implementation for Rails 8 AI Resume Parser

---

## 📋 Table of Contents
1. [Overview](#overview)
2. [Core Files & Architecture](#core-files--architecture)
3. [How It Works](#how-it-works)
4. [Key Components](#key-components)
5. [Usage Examples](#usage-examples)
6. [Maintenance & Troubleshooting](#maintenance--troubleshooting)

---

## 🎯 Overview

This Rails 8 application implements **schema-based multi-tenancy** using the Apartment gem, allowing multiple organizations to use the same application with complete data isolation.

### ✅ What We Achieved
- **Rails 8 Compatibility**: Manual patches applied to Apartment gem
- **Schema-Based Isolation**: Each tenant gets their own PostgreSQL schema
- **Admin Interface**: Global admin panel accessible via `all.airesumeparser.com`
- **Dynamic Subdomain Routing**: `tenant.airesumeparser.com` routes to tenant data
- **Tenant Management**: Pause/activate tenants with schema creation handling

---

## 🏗️ Core Files & Architecture

### 1. **Apartment Gem (Patched for Rails 8)**
```
apartment-2.2.1/
├── lib/apartment/
│   ├── adapters/postgresql_adapter.rb     # Rails 8 compatibility fixes
│   ├── migrator.rb                        # Migration context updates
│   └── tenant.rb                          # File.exist? method fixes
└── apartment.gemspec                      # ActiveRecord dependency < 9.0
```

**Key Changes Applied:**
- Updated `activerecord` dependency to `< 9.0`
- Fixed `File.exist?` method calls to `File.exist?`
- Updated migration context handling for Rails 8

### 2. **Custom Elevator (Subdomain Router)**
```ruby
# lib/apartment/elevators/admin_subdomain.rb
class AdminSubdomain < Apartment::Elevators::Subdomain
  def parse_tenant_name(request)
    subdomain = extract_subdomain(request.host)
    
    # Special handling for admin subdomain
    return 'public' if subdomain == 'all'
    
    # Find tenant by subdomain with direct SQL
    result = ActiveRecord::Base.connection.execute(
      "SELECT schema_name FROM tenants WHERE subdomain = '#{subdomain}' AND status = 'active' LIMIT 1"
    )
    
    result.any? ? result.first['schema_name'] : nil
  end
end
```

### 3. **Tenant Model**
```ruby
# app/models/tenant.rb
class Tenant < ApplicationRecord
  # Status management
  def activate!
    ActiveRecord::Base.transaction do
      update!(status: 'active')
      unless create_apartment_tenant_if_needed
        raise ActiveRecord::RecordInvalid.new(self)
      end
    end
  end

  def pause!
    update!(status: 'inactive')
  end

  # Schema existence check
  def apartment_tenant_exists?
    result = ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql_array([
        "SELECT 1 FROM information_schema.schemata WHERE schema_name = ?", 
        schema_name
      ])
    )
    result.any?
  end
end
```

### 4. **Admin Controllers**
```ruby
# app/controllers/admin/tenants_controller.rb
class Admin::TenantsController < ApplicationController
  before_action :ensure_admin_subdomain!  # Only allow 'all' subdomain access
  
  def activate
    if @tenant.activate!
      redirect_to admin_tenants_path, notice: 'Tenant activated successfully.'
    else
      redirect_to admin_tenants_path, alert: 'Failed to activate tenant.'
    end
  end

  def pause
    if @tenant.pause!
      redirect_to admin_tenants_path, notice: 'Tenant paused successfully.'
    else
      redirect_to admin_tenants_path, alert: 'Failed to pause tenant.'
    end
  end
end
```

### 5. **Configuration Files**

#### Apartment Configuration
```ruby
# config/initializers/apartment.rb
Apartment.configure do |config|
  config.excluded_models = %w{ Tenant User }
  config.tenant_names = lambda { 
    Tenant.active.pluck(:schema_name) 
  }
  config.use_schemas = true
end

# Use custom elevator
Rails.application.config.middleware.use Apartment::Elevators::AdminSubdomain
```

#### Routes
```ruby
# config/routes.rb
Rails.application.routes.draw do
  # Admin interface accessible via all.airesumeparser.com subdomain
  namespace :admin do
    resources :tenants do
      member do
        patch :activate
        patch :pause
      end
    end
  end
  
  # Catch-all route (excludes admin paths)
  get '*path', to: 'dashboard#index', constraints: lambda { |req|
    !req.xhr? && req.format.html? && !req.path.start_with?('/admin')
  }
end
```

---

## ⚙️ How It Works

### 1. **Request Flow**
```
User Request: acme.airesumeparser.com/resumes
     ↓
AdminSubdomain Elevator
     ↓
Checks: subdomain = 'acme'
     ↓
SQL Query: SELECT schema_name FROM tenants WHERE subdomain = 'acme' AND status = 'active'
     ↓
Result: schema_name = 'acme_corp'
     ↓
SET search_path TO "acme_corp"
     ↓
Application serves data from acme_corp schema
```

### 2. **Admin Access Flow**
```
User Request: all.airesumeparser.com/admin
     ↓
AdminSubdomain Elevator
     ↓
Checks: subdomain = 'all'
     ↓
Returns: 'public' schema
     ↓
Admin controller checks: ensure_admin_subdomain!
     ↓
Serves global admin interface
```

### 3. **Database Schema Structure**
```
PostgreSQL Database
├── public (global schema)
│   ├── tenants (tenant management)
│   ├── users (global user accounts)
│   └── schema_migrations
├── acme_corp (tenant schema)
│   ├── resumes
│   ├── job_descriptions
│   └── resume_processings
├── techstart (tenant schema)
│   ├── resumes
│   ├── job_descriptions
│   └── resume_processings
└── test (tenant schema)
    ├── resumes
    ├── job_descriptions
    └── resume_processings
```

---

## 🔧 Key Components

### 1. **Tenant Management**
- **Creation**: Creates both database record and PostgreSQL schema
- **Activation**: Enables tenant and ensures schema exists
- **Pause**: Disables tenant (schema remains for data preservation)
- **Validation**: Ensures unique subdomain and schema names

### 2. **Schema Management**
- **Automatic Creation**: Schemas created when tenant is activated
- **Existence Checking**: Prevents duplicate schema creation errors
- **Migration**: Runs on all tenant schemas automatically

### 3. **Access Control**
- **Admin Subdomain**: Only accessible via `all.airesumeparser.com`
- **Tenant Isolation**: Users only see their tenant's data
- **Schema Switching**: Automatic per-request schema switching

### 4. **Navigation Logic**
```ruby
# app/helpers/application_helper.rb
def admin_subdomain?
  host = request.host
  
  if Rails.env.development? && host.include?('localhost')
    return request.host.start_with?('all.')
  end
  
  subdomain = host.split('.').first
  subdomain == 'all'
end
```

---

## 💻 Usage Examples

### 1. **Creating a New Tenant**
```ruby
# Via Rails console or admin interface
tenant = Tenant.create!(
  name: "Acme Corporation", 
  subdomain: "acme", 
  schema_name: "acme_corp",
  status: "active"
)
# This automatically creates the PostgreSQL schema "acme_corp"
```

### 2. **Accessing Tenant Data**
```bash
# Access tenant's application
http://acme.airesumeparser.com

# Access admin interface
http://all.airesumeparser.com/admin
```

### 3. **Manual Schema Operations**
```bash
# Check schema sync status
rails tenant:sync_schemas

# Fix existing schema conflicts
rails tenant:fix_existing_schema[5]

# Drop specific schema (careful!)
rails tenant:drop_schema[schema_name]
```

### 4. **Development URLs**
```bash
# Local development
http://acme.localhost:3000      # Tenant access
http://all.localhost:3000/admin # Admin access
```

---

## 🛠️ Maintenance & Troubleshooting

### 1. **Common Issues & Solutions**

#### Schema Already Exists Error
```
Error: PG::DuplicateSchema: ERROR: schema "test" already exists
Solution: Fixed with smart schema existence checking
```

#### Navigation Showing on Wrong Subdomain
```
Problem: Regular app navigation showing on admin subdomain
Solution: Updated admin_subdomain? helper and catch-all route exclusion
```

#### Tenant Activation Fails
```
Problem: Schema creation errors during activation
Solution: Added graceful error handling and existence checks
```

### 2. **Maintenance Tasks**
```ruby
# Clean up orphaned schemas
rails tenant:sync_schemas

# Manually fix tenant with existing schema
rails tenant:fix_existing_schema[tenant_id]

# Check all tenant statuses
Tenant.all.each { |t| puts "#{t.name}: #{t.status} - Schema exists: #{t.schema_exists?}" }
```

### 3. **Monitoring & Logging**
The system logs key events:
- Schema creation/existence checks
- Tenant activation/pause operations
- Subdomain routing decisions
- Error conditions and resolutions

---

## 🎉 Benefits Achieved

✅ **Complete Data Isolation**: Each tenant has their own PostgreSQL schema  
✅ **Scalable Architecture**: Add unlimited tenants without performance impact  
✅ **Admin Management**: Centralized tenant administration  
✅ **Rails 8 Compatible**: Successfully patched Apartment gem for latest Rails  
✅ **Robust Error Handling**: Graceful handling of schema conflicts  
✅ **Production Ready**: Proper domain routing and access controls  

---

## 📚 Files Summary

### Essential Files for Multi-Tenancy:
1. `apartment-2.2.1/` - Patched Apartment gem
2. `lib/apartment/elevators/admin_subdomain.rb` - Custom routing
3. `config/initializers/apartment.rb` - Configuration
4. `app/models/tenant.rb` - Tenant management
5. `app/controllers/admin/` - Admin interface
6. `lib/tasks/tenant_maintenance.rake` - Maintenance tasks

### Supporting Files:
1. `app/helpers/application_helper.rb` - Navigation logic
2. `config/routes.rb` - Routing configuration
3. `app/views/admin/` - Admin interface views
4. `db/seeds.rb` - Sample tenant data

This implementation provides a robust, scalable multi-tenant architecture that properly isolates data while maintaining ease of administration and development.