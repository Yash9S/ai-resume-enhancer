# 🏢 **Video Guide 1: Multi-Tenancy Implementation in AI Resume Parser**

## 📋 **Overview**
This guide explains how multi-tenancy is implemented using the Apartment gem with PostgreSQL schemas for tenant isolation.

---

## 🎯 **Video Recording Focus Points**

### **1. Core Concept Explanation** (2-3 minutes)
- What is multi-tenancy?
- Why PostgreSQL schemas instead of separate databases?
- How tenant isolation works

### **2. File Structure Overview** (3-4 minutes)īī
```
Key Files to Show:
├── config/initializers/apartment.rb           # Main configuration
├── lib/apartment/elevators/admin_subdomain.rb # Custom elevatorī
├── app/models/tenant.rb                       # Tenant model
└── config/initializers/apartment_rails8_patch.rb # Rails 8 compatibility
```

---

## 📁 **File #1: Core Apartment Configuration**

### **📄 File: `config/initializers/apartment.rb`**

**Show this exact code in your video:**

```ruby
# You can have Apartment route to the appropriate Tenant by adding some Rack middleware.
# Apartment can support many different "Elevators" that can take care of this routing to your data.
# Require whichever Elevator you're using below or none if you have a custom one.

# Require our custom admin elevator
require_relative '../../lib/apartment/elevators/admin_subdomain'

#
# Apartment Configuration
#
Apartment.configure do |config|

  # Add any models that you do not want to be multi-tenanted, but remain in the global (public) namespace.
  # A typical example would be a Customer or Tenant model that stores each Tenant's information.
  #
  config.excluded_models = %w{ Tenant User }

  # Dynamic tenant names from Tenant model
  config.tenant_names = lambda { 
    begin
      Tenant.active.pluck(:schema_name) 
    rescue
      [] # Return empty array if Tenant table doesn't exist yet
    end
  }

  # Use PostgreSQL schemas for better performance and easier management
  config.use_schemas = true

  #
  # ==> PostgreSQL only options

  # Apartment can be forced to use raw SQL dumps instead of schema.rb for creating new schemas.
  # Use this when you are using some extra features in PostgreSQL that can't be represented in
  # schema.rb, like materialized views etc. (only applies with use_schemas set to true).
  # (Note: this option doesn't use db/structure.sql, it creates SQL dump by executing pg_dump)
  #
  # config.use_sql = false

  # There are cases where you might want some schemas to always be in your search_path
  # e.g when using a PostgreSQL extension like hstore.
  # Any schemas added here will be available along with your selected Tenant.
  #
  # config.persistent_schemas = %w{ hstore }

  # <== PostgreSQL only options
  #

  # By default, and only when not using PostgreSQL schemas, Apartment will prepend the environment
  # to the tenant name to ensure there is no conflict between your environments.
  # This is mainly for the benefit of your development and test environments.
  # Uncomment the line below if you want to disable this behaviour in production.
  #
  # config.prepend_environment = !Rails.env.production?

  # When using PostgreSQL schemas, the database dump will be namespaced, and
  # apartment will substitute the default namespace (usually public) with the
  # name of the new tenant when creating a new tenant. Some items must maintain
  # a reference to the default namespace (ie public) - for instance, a default
  # uuid generation. Uncomment the line below to create a list of namespaced
  # items in the schema dump that should *not* have their namespace replaced by
  # the new tenant
  #
  # config.pg_excluded_names = ["uuid_generate_v4"]
end

# Setup a custom Tenant switching middleware. The Proc should return the name of the Tenant that
# you want to switch to.
# Rails.application.config.middleware.use Apartment::Elevators::Generic, lambda { |request|
#   request.host.split('.').first
# }

# Rails.application.config.middleware.use Apartment::Elevators::Domain
Rails.application.config.middleware.use Apartment::Elevators::AdminSubdomain
# Rails.application.config.middleware.use Apartment::Elevators::FirstSubdomain
# Rails.application.config.middleware.use Apartment::Elevators::Host
```

**🎥 Explain in Video:**
1. **Line 8**: Custom elevator requirement
2. **Line 17**: Excluded models stay in public schema
3. **Line 20-25**: Dynamic tenant loading from database
4. **Line 28**: PostgreSQL schema-based approach
5. **Line 67**: Using our custom AdminSubdomain elevator

---

## 📁 **File #2: Custom Elevator (Schema Switching Logic)**

### **📄 File: `lib/apartment/elevators/admin_subdomain.rb`**

**Show this exact code in your video:**

```ruby
# Custom Apartment Elevator for Admin Interface
# This elevator handles the special 'all' subdomain for global admin access

require 'apartment/elevators/subdomain'

module Apartment
  module Elevators
    class AdminSubdomain < Apartment::Elevators::Subdomain
      def parse_tenant_name(request)
        # Extract subdomain from host
        host = request.host
        subdomain = extract_subdomain(host)
        
        # Special handling for admin subdomain
        if subdomain == 'all'
          # Switch to public schema for global admin access
          return 'public'
        end
        
        # For other subdomains, find the corresponding tenant
        if subdomain.present?
          # Query the tenants table directly from public schema
          begin
            # Use raw SQL to avoid apartment schema switching issues in elevator
            result = ActiveRecord::Base.connection.execute(
              "SELECT schema_name FROM tenants WHERE subdomain = '#{subdomain}' AND status = 'active' LIMIT 1"
            )
            
            if result.any?
              schema_name = result.first['schema_name']
              return schema_name
            end
          rescue => e
            Rails.logger.error "Error finding tenant in elevator: #{e.message}"
            return nil
          end
        end
        
        # Default to public schema if no subdomain or tenant not found
        nil
      end

      private

      def extract_subdomain(host)
        return nil unless host
        
        # Remove port if present
        host_without_port = host.split(':').first
        
        # Split by dots and get the first part (subdomain)
        parts = host_without_port.split('.')
        
        # Return subdomain if we have more than 2 parts (subdomain.domain.tld)
        # or if we're on localhost with subdomain (subdomain.localhost)
        if parts.length > 2 || (parts.length == 2 && parts.last == 'localhost')
          return parts.first
        end
        
        nil
      end
    end
  end
end
```

**🎥 Explain in Video:**
1. **Line 9-12**: Extract subdomain from request
2. **Line 15-18**: Special 'all' subdomain for admin access
3. **Line 21-35**: Database lookup for tenant schema
4. **Line 25-26**: Raw SQL to avoid circular dependencies
5. **Line 44-57**: Subdomain extraction logic

---

## 📁 **File #3: Tenant Model Structure**

### **📄 File: `app/models/tenant.rb`** (Show this structure)

```ruby
class Tenant < ApplicationRecord
  # This model stays in the public schema (excluded_models configuration)
  
  validates :name, presence: true, uniqueness: true
  validates :subdomain, presence: true, uniqueness: true
  validates :schema_name, presence: true, uniqueness: true
  validates :status, presence: true
  
  enum status: { active: 'active', inactive: 'inactive', suspended: 'suspended' }
  
  scope :active, -> { where(status: 'active') }
  
  before_validation :generate_schema_name, on: :create
  after_create :create_tenant_schema
  before_destroy :drop_tenant_schema
  
  private
  
  def generate_schema_name
    self.schema_name = "tenant_#{subdomain.parameterize.underscore}" if subdomain.present?
  end
  
  def create_tenant_schema
    Apartment::Tenant.create(schema_name)
    Rails.logger.info "Created tenant schema: #{schema_name}"
  rescue Apartment::SchemaExists
    Rails.logger.warn "Schema #{schema_name} already exists"
  end
  
  def drop_tenant_schema
    Apartment::Tenant.drop(schema_name)
    Rails.logger.info "Dropped tenant schema: #{schema_name}"
  rescue Apartment::SchemaNotFound
    Rails.logger.warn "Schema #{schema_name} not found for deletion"
  end
end
```

**🎥 Explain in Video:**
1. **Line 2**: Stays in public schema (not multi-tenanted)
2. **Line 13**: Auto-generates schema name from subdomain
3. **Line 14**: Creates PostgreSQL schema on tenant creation
4. **Line 23-27**: Apartment gem integration for schema creation

---

## 📁 **File #4: Rails 8 Compatibility**

### **📄 File: `config/initializers/apartment_rails8_patch.rb`**

```ruby
# Rails 8 compatibility patch for Apartment gem
# This addresses conflicts between Apartment and Rails 8's Propshaft

module Apartment
  module Adapters
    class PostgresqlSchemaAdapter
      # Override to handle Rails 8 Propshaft compatibility
      def create(tenant)
        # Ensure we're in the public schema before creating
        switch_to_public_schema
        
        # Create the schema
        ActiveRecord::Base.connection.execute("CREATE SCHEMA \"#{tenant}\"")
        
        # Set search path and load schema
        ActiveRecord::Base.connection.schema_search_path = tenant
        
        # Load the schema structure
        load_schema_into_tenant(tenant)
        
        Rails.logger.info "Created tenant schema: #{tenant}"
      end
      
      private
      
      def switch_to_public_schema
        ActiveRecord::Base.connection.schema_search_path = 'public'
      end
      
      def load_schema_into_tenant(tenant)
        # Rails 8 compatible schema loading
        if Rails.env.development? || Rails.env.test?
          ActiveRecord::Tasks::DatabaseTasks.load_schema_current(:ruby)
        else
          # Use SQL structure in production for better compatibility
          ActiveRecord::Tasks::DatabaseTasks.load_schema_current(:sql)
        end
      end
    end
  end
end
```

**🎥 Explain in Video:**
1. **Line 6**: Override for Rails 8 compatibility
2. **Line 9**: Ensure public schema before creation
3. **Line 12**: Create new PostgreSQL schema
4. **Line 15**: Switch to new schema
5. **Line 18**: Load Rails schema into new tenant

---

## 🔄 **Schema Switching Flow Demonstration**

### **Show this flow in your terminal during video:**

```bash
# 1. Connect to PostgreSQL and show schemas
psql -d ai_resume_parser_development
\dn

# Expected output:
#   Name    |  Owner   
# ----------+----------
#  public   | postgres
#  tenant_acme | postgres  
#  tenant_techcorp | postgres

# 2. Show table structure in different schemas
\dt public.*      # Global tables (tenants, users)
\dt tenant_acme.* # Tenant-specific tables (resumes, job_postings)

# 3. Rails console demonstration
rails console

# Switch between tenants
Apartment::Tenant.current
# => "public"

Apartment::Tenant.switch!('tenant_acme')
Apartment::Tenant.current  
# => "tenant_acme"

# Data isolation test
Resume.count  # Count in acme tenant

Apartment::Tenant.switch!('tenant_techcorp')  
Resume.count  # Different count in techcorp tenant
```

---

## 🎯 **Key Points to Emphasize in Video**

### **1. Schema Isolation Benefits**
- **Performance**: Single database, multiple schemas
- **Security**: Complete data separation
- **Maintenance**: Shared migrations, isolated data

### **2. Request Flow**
```
Request: acme.yourdomain.com
    ↓
AdminSubdomain Elevator
    ↓
extract_subdomain('acme')
    ↓
Database lookup: tenants WHERE subdomain = 'acme'
    ↓
Switch to schema: 'tenant_acme'
    ↓
All queries now run in tenant_acme schema
```

### **3. Special Cases**
- **all.yourdomain.com** → Public schema (admin access)
- **No subdomain** → Public schema (default)
- **Invalid subdomain** → Public schema (fallback)

### **4. Database Structure**
```sql
-- Global Schema (public)
public.tenants           -- Tenant configurations
public.users             -- Global user management

-- Tenant Schemas  
tenant_acme.resumes      -- Acme's resumes
tenant_acme.job_postings -- Acme's job postings
tenant_techcorp.resumes  -- TechCorp's resumes
tenant_techcorp.job_postings -- TechCorp's job postings
```

---

## 📝 **Video Script Outline**

1. **Introduction** (30s)
   - "Today I'll explain multi-tenancy implementation using Apartment gem"

2. **Core Configuration** (2m)
   - Show `apartment.rb` file
   - Explain excluded models and tenant loading

3. **Custom Elevator** (3m)
   - Show `admin_subdomain.rb` file
   - Explain subdomain parsing and schema switching

4. **Tenant Model** (2m)
   - Show tenant creation and schema management

5. **Live Demo** (2m)
   - Terminal commands showing schema switching
   - Rails console demonstration

6. **Summary** (30s)
   - Key benefits and architecture overview

**Total Duration: ~8 minutes**