# Comprehensive Rails 8 compatibility patch for Apartment gem
# This patches the apartment gem to work with Rails 8.x

# First, require apartment safely
begin
  require 'apartment'
rescue LoadError => e
  Rails.logger.error "Failed to load apartment gem: #{e.message}"
  raise e
end

if defined?(Apartment) && Rails::VERSION::MAJOR >= 8
  Rails.logger.info "Applying Rails 8 compatibility patches to Apartment gem"

  # Patch 1: Fix connection_config method which was renamed in Rails 8
  module Apartment
    module Tenant
      class << self
        def config
          @config ||= begin
            if defined?(ActiveRecord::Base.connection_db_config)
              ActiveRecord::Base.connection_db_config.configuration_hash
            elsif defined?(ActiveRecord::Base.connection_config)
              ActiveRecord::Base.connection_config
            else
              Rails.application.config.database_configuration[Rails.env]
            end
          end
        end
      end
    end

    # Patch 2: Fix module-level connection methods
    class << self
      def connection_config
        if defined?(ActiveRecord::Base.connection_db_config)
          ActiveRecord::Base.connection_db_config.configuration_hash
        elsif defined?(ActiveRecord::Base.connection_config)
          ActiveRecord::Base.connection_config
        else
          Rails.application.config.database_configuration[Rails.env]
        end
      end

      def connection_db_config
        ActiveRecord::Base.connection_db_config if defined?(ActiveRecord::Base.connection_db_config)
      end
    end
  end

  # Patch 3: PostgreSQL adapter compatibility
  if defined?(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.class_eval do
      unless method_defined?(:schema_search_path)
        def schema_search_path
          @schema_search_path ||= query_value("SHOW search_path", "SCHEMA")
        end

        def schema_search_path=(search_path)
          @schema_search_path = search_path
          execute("SET search_path TO #{search_path}", "SCHEMA")
        end
      end
    end
  end

  # Patch 4: Fix version checking methods
  if defined?(Apartment::Adapters::AbstractAdapter)
    Apartment::Adapters::AbstractAdapter.class_eval do
      private

      def rails_version_too_new?
        false # Disable version checking for Rails 8
      end
    end
  end

  # Patch 5: Ensure ActiveRecord extensions work
  module Apartment
    module ActiveRecordExtensions
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def connection_config
          if defined?(connection_db_config)
            connection_db_config.configuration_hash
          else
            Rails.application.config.database_configuration[Rails.env]
          end
        end
      end
    end
  end

  # Apply patches only if not already applied
  unless ActiveRecord::Base.included_modules.include?(Apartment::ActiveRecordExtensions)
    ActiveRecord::Base.send(:include, Apartment::ActiveRecordExtensions)
  end

  Rails.logger.info "Rails 8 compatibility patches applied successfully"

end