# You can have Apartment route to the appropriate Tenant by adding some Rack middleware.
# Apartment can support many different "Elevators" that can take care of this routing to your data.
# Require whichever Elevator you're using below or none if you have a custom one.
#
# require 'apartment/elevators/generic'
# require 'apartment/elevators/domain'
# require 'apartment/elevators/subdomain'
# require 'apartment/elevators/first_subdomain'
# require 'apartment/elevators/host'

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

  # Use MySQL databases for multi-tenancy (MySQL doesn't support schemas like PostgreSQL)
  config.use_schemas = false

  # MySQL specific configuration for tenant database creation
  # tenant_names should return just the tenant identifiers (schema_name)
  config.tenant_names = lambda { 
    begin
      Tenant.active.pluck(:schema_name) 
    rescue
      [] # Return empty array if Tenant table doesn't exist yet
    end
  }

  # For MySQL databases, Apartment will use: database_name + "_" + tenant_name
  # So ai_resume_parser_development + "_" + "acme" = "ai_resume_parser_development_acme"
  # But we want ai_resume_parser_acme, so we need to customize this
  
  # Disable prepend_environment to avoid ai_resume_parser_development_acme
  config.prepend_environment = false

  # MySQL configuration for database creation
  # When using MySQL databases for tenants, each tenant gets its own database
  # The main database contains the public tables (Users, Tenants)
  # Each tenant database contains the tenant-specific tables (Resumes, etc.)
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
