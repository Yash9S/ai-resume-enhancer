class Tenant < ApplicationRecord
  # Associations
  has_many :users, dependent: :destroy

  # Validations
  validates :name, presence: true, uniqueness: true
  validates :subdomain, presence: true, uniqueness: true, format: { with: /\A[a-z0-9\-]+\z/ }
  validates :schema_name, presence: true, uniqueness: true, format: { with: /\A[a-z0-9_]+\z/ }
  validates :status, presence: true, inclusion: { in: %w[active inactive pending] }

  before_validation :generate_schema_name, on: :create
  after_create :create_apartment_tenant
  after_destroy :drop_apartment_tenant

  scope :active, -> { where(status: 'active') }

  # Status management methods
  def activate!
    ActiveRecord::Base.transaction do
      update!(status: 'active')
      
      # Ensure schema and tables exist before activation (create if missing)
      unless apartment_tenant_exists?
        Rails.logger.info "Schema missing for #{name}, creating during activation..."
        create_schema_and_copy_structure
      end
      
      # Log successful activation
      Rails.logger.info "Successfully activated tenant #{id} (#{name}) with schema #{schema_name}"
      true
    end
  rescue => e
    # Wrap errors in RecordInvalid for consistent handling
    errors.add(:base, "Activation failed: #{e.message}")
    Rails.logger.error "Failed to activate tenant #{id}: #{e.message}"
    raise ActiveRecord::RecordInvalid.new(self)
  end

  def pause!
    update!(status: 'inactive')
  end

  def paused?
    status == 'inactive'
  end

  def active?
    status == 'active'
  end

  # Class method to sync database schemas with tenant records (MySQL version)
  def self.sync_schemas
    # Get all existing tenant databases from MySQL (simple names, no prefix)
    result = ActiveRecord::Base.connection.execute(
      "SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME NOT IN ('ai_resume_parser_development', 'ai_resume_parser_test', 'ai_resume_parser_production', 'information_schema', 'mysql', 'performance_schema', 'sys')"
    )
    existing_databases = result.map { |row| row['SCHEMA_NAME'] }
    
    # Get all tenant database names that should exist (simple names)
    active_tenant_databases = Tenant.active.pluck(:schema_name)
    
    Rails.logger.info "Existing tenant databases: #{existing_databases}"
    Rails.logger.info "Active tenant databases: #{active_tenant_databases}"
    
    # Find orphaned databases (exist in MySQL but no active tenant)
    orphaned_databases = existing_databases - active_tenant_databases
    Rails.logger.info "Orphaned databases found: #{orphaned_databases}" if orphaned_databases.any?
    
    orphaned_databases
  end

  # Check if apartment schema exists (public method for rake tasks)
  def schema_exists?
    apartment_tenant_exists?
  end

  private

  def generate_schema_name
    self.schema_name = subdomain.underscore if subdomain.present? && schema_name.blank?
  end

  def create_apartment_tenant
    # Always create schema when tenant is created, regardless of status
    # This ensures the database structure is ready when tenant is activated
    Rails.logger.info "Creating apartment tenant for #{name} (#{schema_name})"
    
    # Use the proven working approach - copy structure instead of running migrations
    create_schema_and_copy_structure
  rescue => e
    Rails.logger.error "Failed to create apartment tenant #{schema_name}: #{e.message}"
    Rails.logger.error "Error details: #{e.class} - #{e.backtrace&.first(3)&.join(', ')}"
    # Don't fail tenant creation if schema creation fails - it can be retried later
    false
  end

  # Create database and copy table structure for MySQL
  def create_schema_and_copy_structure
    return true if apartment_tenant_exists?
    
    # Use simple database name (no prefix) as configured in apartment.rb
    tenant_db_name = schema_name
    Rails.logger.info "Creating database and copying structure for: #{tenant_db_name}"
    
    # Create the tenant database
    ActiveRecord::Base.connection.execute(
      "CREATE DATABASE IF NOT EXISTS `#{tenant_db_name}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
    )
    Rails.logger.info "Database created: #{tenant_db_name}"
    
    # Switch to new tenant database using Apartment
    Apartment::Tenant.create(schema_name)
    
    # Run migrations on the new tenant database
    Apartment::Tenant.switch(schema_name) do
      # Run all migrations to set up the database structure
      ActiveRecord::Tasks::DatabaseTasks.migrate
      Rails.logger.info "Migrations completed for tenant database: #{tenant_db_name}"
    end
    
    Rails.logger.info "Successfully created database and tables for #{tenant_db_name}"
    true
    
  rescue ActiveRecord::StatementInvalid => e
    if e.message.include?("database exists")
      Rails.logger.info "Database #{tenant_db_name} already exists"
      true
    else
      Rails.logger.error "Failed to create database #{tenant_db_name}: #{e.message}"
      false
    end
  rescue => e
    Rails.logger.error "Failed to create tenant database #{tenant_db_name}: #{e.message}"
    false
  end

  # Find a working tenant database to use as reference (MySQL version)
  def find_working_tenant_for_copy
    # Try to find an active tenant with all required tables
    Tenant.where.not(id: id).active.find_each do |tenant|
      next unless tenant.schema_exists?
      
      begin
        Apartment::Tenant.switch(tenant.schema_name) do
          required_tables = %w[resumes job_descriptions resume_processings]
          if required_tables.all? { |table| ActiveRecord::Base.connection.table_exists?(table) }
            return tenant.schema_name
          end
        end
      rescue
        next
      end
    end
    
    # If no tenant database works, use the main database for reference
    nil # Let Apartment handle database creation with migrations
  end

  def create_apartment_tenant_if_needed
    return true unless status == 'active'
    
    # Double-check if schema exists before creating
    if apartment_tenant_exists?
      Rails.logger.info "Schema #{schema_name} already exists, skipping creation"
      return true
    end
    
    # Create schema outside of the main transaction to avoid transaction conflicts
    begin
      # Execute schema creation in a separate connection to avoid transaction issues
      ActiveRecord::Base.connection.execute("CREATE SCHEMA IF NOT EXISTS #{ActiveRecord::Base.connection.quote_column_name(schema_name)}")
      
      # Run migrations on the new schema in a more robust way
      begin
        Apartment::Tenant.switch(schema_name) do
          # Check if there are any pending migrations before running them
          if ActiveRecord::Base.connection.migration_context.needs_migration?
            Rails.logger.info "Running migrations for schema #{schema_name}"
            ActiveRecord::Tasks::DatabaseTasks.migrate
          else
            Rails.logger.info "No migrations needed for schema #{schema_name}"
          end
        end
      rescue => migration_error
        Rails.logger.warn "Migration error for #{schema_name}: #{migration_error.message}"
        # Still consider this a success since the basic schema was created
        # The admin can run migrations manually if needed
      end
      
      Rails.logger.info "Successfully created schema #{schema_name}"
      true
    rescue PG::DuplicateSchema => e
      Rails.logger.warn "Schema #{schema_name} already exists: #{e.message}"
      true # Consider this a success since the schema exists
    rescue => e
      Rails.logger.error "Failed to create schema #{schema_name}: #{e.message}"
      Rails.logger.error "Error details: #{e.class} - #{e.backtrace&.first(3)&.join(', ')}"
      false
    end
  end

  def apartment_tenant_exists?
    # Use MySQL query to check if tenant database exists
    # Use simple database name (no prefix) as configured in apartment.rb
    tenant_db_name = schema_name
    result = ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql_array([
        "SELECT 1 FROM information_schema.SCHEMATA WHERE SCHEMA_NAME = ?", 
        tenant_db_name
      ])
    )
    result.any?
  rescue => e
    Rails.logger.error "Failed to check tenant database existence #{tenant_db_name}: #{e.message}"
    false
  end

  def drop_apartment_tenant
    if schema_name.present?
      # Drop the tenant database in MySQL
      # Use simple database name (no prefix) as configured in apartment.rb
      tenant_db_name = schema_name
      Apartment::Tenant.drop(schema_name)
      Rails.logger.info "Dropped tenant database: #{tenant_db_name}"
    end
  rescue => e
    Rails.logger.error "Failed to drop apartment tenant database #{schema_name}: #{e.message}"
  end
end
