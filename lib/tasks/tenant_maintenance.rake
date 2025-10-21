namespace :tenant do
  desc "Sync database schemas with tenant records"
  task sync_schemas: :environment do
    puts "Syncing tenant schemas..."
    
    orphaned_schemas = Tenant.sync_schemas
    
    if orphaned_schemas.any?
      puts "Found #{orphaned_schemas.length} orphaned schemas:"
      orphaned_schemas.each do |schema|
        puts "  - #{schema}"
      end
      
      puts "\nTo clean up orphaned schemas, you can:"
      puts "1. Reactivate corresponding tenant records, or"
      puts "2. Manually drop unused schemas with: rails tenant:drop_schema[schema_name]"
    else
      puts "All schemas are properly synced with active tenants."
    end
  end
  
  desc "Drop a specific schema (use with caution)"
  task :drop_schema, [:schema_name] => :environment do |task, args|
    schema_name = args[:schema_name]
    
    if schema_name.blank?
      puts "Usage: rails tenant:drop_schema[schema_name]"
      exit 1
    end
    
    begin
      Apartment::Tenant.drop(schema_name)
      puts "Successfully dropped schema: #{schema_name}"
    rescue => e
      puts "Error dropping schema #{schema_name}: #{e.message}"
      exit 1
    end
  end
  
  desc "Fix tenant with existing schema"
  task :fix_existing_schema, [:tenant_id] => :environment do |task, args|
    tenant_id = args[:tenant_id]
    
    if tenant_id.blank?
      puts "Usage: rails tenant:fix_existing_schema[tenant_id]"
      exit 1
    end
    
    tenant = Tenant.find(tenant_id)
    
    puts "Fixing tenant: #{tenant.name} (#{tenant.schema_name})"
    
    if tenant.schema_exists?
      puts "Schema already exists, just updating status..."
      tenant.update!(status: 'active')
      puts "Successfully activated tenant without creating new schema."
    else
      puts "Schema doesn't exist, creating new one..."
      tenant.activate!
      puts "Successfully created schema and activated tenant."
    end
  rescue => e
    puts "Error fixing tenant: #{e.message}"
    exit 1
  end
end