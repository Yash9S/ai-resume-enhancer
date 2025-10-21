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