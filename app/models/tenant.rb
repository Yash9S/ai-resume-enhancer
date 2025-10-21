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

  # Class method to sync database schemas with tenant records
  def self.sync_schemas
    # Get all existing schemas from database
    result = ActiveRecord::Base.connection.execute(
      "SELECT schema_name FROM information_schema.schemata WHERE schema_name NOT IN ('information_schema', 'pg_catalog', 'pg_toast', 'pg_temp_1', 'pg_toast_temp_1', 'public')"
    )
    existing_schemas = result.map { |row| row['schema_name'] }
    
    # Get all tenant schema names that should exist
    active_tenant_schemas = Tenant.active.pluck(:schema_name)
    
    Rails.logger.info "Existing schemas: #{existing_schemas}"
    Rails.logger.info "Active tenant schemas: #{active_tenant_schemas}"
    
    # Find orphaned schemas (exist in DB but no active tenant)
    orphaned_schemas = existing_schemas - active_tenant_schemas
    Rails.logger.info "Orphaned schemas found: #{orphaned_schemas}" if orphaned_schemas.any?
    
    orphaned_schemas
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

  # Create schema and copy table structure (proven working approach)
  def create_schema_and_copy_structure
    return true if apartment_tenant_exists?
    
    Rails.logger.info "Creating schema and copying structure for: #{schema_name}"
    
    # Create the schema
    ActiveRecord::Base.connection.execute(
      "CREATE SCHEMA IF NOT EXISTS #{ActiveRecord::Base.connection.quote_column_name(schema_name)}"
    )
    Rails.logger.info "Schema created: #{schema_name}"
    
    # Find a working schema to copy from
    working_schema = find_working_schema_for_copy
    Rails.logger.info "Copying structure from: #{working_schema}"
    
    # Switch to new schema and copy tables
    Apartment::Tenant.switch(schema_name) do
      # Copy all necessary tables
      tables_to_copy = %w[users resumes job_descriptions resume_processings active_storage_blobs active_storage_attachments active_storage_variant_records]
      
      tables_to_copy.each do |table|
        begin
          ActiveRecord::Base.connection.execute(
            "CREATE TABLE #{table} (LIKE #{working_schema}.#{table} INCLUDING ALL)"
          )
          Rails.logger.info "Copied table: #{table}"
        rescue PG::DuplicateTable
          Rails.logger.info "Table #{table} already exists"
        rescue => e
          Rails.logger.warn "Failed to copy table #{table}: #{e.message}"
        end
      end
      
      # Copy schema_migrations table and records
      begin
        ActiveRecord::Base.connection.execute(
          "CREATE TABLE IF NOT EXISTS schema_migrations (LIKE #{working_schema}.schema_migrations INCLUDING ALL)"
        )
        ActiveRecord::Base.connection.execute(
          "INSERT INTO schema_migrations (version) 
           SELECT version FROM #{working_schema}.schema_migrations 
           ON CONFLICT (version) DO NOTHING"
        )
        Rails.logger.info "Copied migration records from #{working_schema}"
      rescue => e
        Rails.logger.warn "Failed to copy migration records: #{e.message}"
      end
    end
    
    Rails.logger.info "Successfully created schema and tables for #{schema_name}"
    true
    
  rescue PG::DuplicateSchema
    Rails.logger.info "Schema #{schema_name} already exists"
    true
  rescue => e
    Rails.logger.error "Failed to create schema #{schema_name}: #{e.message}"
    false
  end

  # Find a working schema to copy structure from
  def find_working_schema_for_copy
    # Try to find an active tenant with all required tables
    Tenant.where.not(id: id).active.find_each do |tenant|
      next unless tenant.schema_exists?
      
      begin
        Apartment::Tenant.switch(tenant.schema_name) do
          required_tables = %w[users resumes job_descriptions resume_processings]
          if required_tables.all? { |table| ActiveRecord::Base.connection.table_exists?(table) }
            return tenant.schema_name
          end
        end
      rescue
        next
      end
    end
    
    # If no tenant schema works, use public schema as fallback
    'public'
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
    # Use direct PostgreSQL query to check if schema exists
    result = ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql_array([
        "SELECT 1 FROM information_schema.schemata WHERE schema_name = ?", 
        schema_name
      ])
    )
    result.any?
  rescue => e
    Rails.logger.error "Failed to check tenant existence #{schema_name}: #{e.message}"
    false
  end

  def drop_apartment_tenant
    Apartment::Tenant.drop(schema_name) if schema_name.present?
  rescue => e
    Rails.logger.error "Failed to drop apartment tenant #{schema_name}: #{e.message}"
  end
end
