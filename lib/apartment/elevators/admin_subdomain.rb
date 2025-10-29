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
        
        Rails.logger.debug "Apartment Elevator - Host: #{host}, Extracted subdomain: #{subdomain}"
        
        # Special handling for admin subdomain
        if subdomain == 'all'
          Rails.logger.debug "Apartment Elevator - Using admin subdomain, returning nil for main database"
          return nil
        end
        
        # Handle localhost without subdomain - use 'acme' as default for development
        if subdomain.blank? && (host.include?('localhost') || host.include?('127.0.0.1'))
          subdomain = 'acme'
          Rails.logger.debug "Apartment Elevator - No subdomain on localhost, defaulting to 'acme'"
        end
        
        # For other subdomains, find the corresponding tenant
        if subdomain.present?
          begin
            # Use ActiveRecord model to avoid SQL injection and result parsing issues
            tenant_record = ActiveRecord::Base.connection.select_one(
              ActiveRecord::Base.sanitize_sql_array([
                "SELECT schema_name FROM tenants WHERE subdomain = ? AND status = 'active' LIMIT 1",
                subdomain
              ])
            )
            
            if tenant_record && tenant_record['schema_name']
              Rails.logger.debug "Apartment Elevator - Found tenant: #{tenant_record['schema_name']} for subdomain: #{subdomain}"
              return tenant_record['schema_name']
            else
              Rails.logger.warn "Apartment Elevator - No active tenant found for subdomain: #{subdomain}, checking if database exists"
              # Check if database exists directly
              begin
                ActiveRecord::Base.connection.execute("USE #{subdomain}")
                Rails.logger.debug "Apartment Elevator - Database #{subdomain} exists, using it"
                return subdomain
              rescue => db_error
                Rails.logger.warn "Apartment Elevator - Database #{subdomain} does not exist: #{db_error.message}"
              end
            end
          rescue => e
            Rails.logger.error "Error finding tenant in elevator: #{e.message}"
            Rails.logger.error "Subdomain attempted: #{subdomain}"
            Rails.logger.error "Error backtrace: #{e.backtrace.first(5).join(', ')}"
            # Don't return nil immediately, fall through to default
          end
        end
        
        # Default to 'acme' tenant for development
        Rails.logger.debug "Apartment Elevator - Falling back to 'acme' tenant"
        return 'acme'
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