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

  # Set default tenant to acme for MySQL (prevents fallback to 'test')
  config.default_schema = 'acme'

  # Dynamic tenant names from Tenant model
  config.tenant_names = lambda { 
    begin
      # Return active tenant schema names for MySQL databases
      Tenant.where(status: 'active').pluck(:schema_name) 
    rescue ActiveRecord::StatementInvalid, NameError
      # Return empty array during initialization or if Tenant table doesn't exist
      # Don't return ['test'] as it causes apartment to try to switch to non-existent 'test' database
      []
    end
  }

  # Use MySQL databases for multi-tenancy (MySQL doesn't support schemas like PostgreSQL)
  config.use_schemas = false

  # For MySQL: We want databases named exactly like the tenant schema names
  # So "test" tenant should use "test" database (not ai_resume_parser_test)
  # This matches how the databases are currently created
  
  # Disable prepend_environment to use simple tenant names that match existing DBs
  config.prepend_environment = false
  config.append_environment = false
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
