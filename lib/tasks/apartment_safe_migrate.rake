namespace :apartment do
  desc "Migrate only existing tenant databases"
  task migrate_existing: :environment do
    puts "🔍 Checking for existing tenant databases..."
    
    # Get list of existing databases from MySQL
    existing_databases = ActiveRecord::Base.connection.execute("SHOW DATABASES").map { |row| row[0] }
    
    # Filter to only tenant databases (exclude system databases)
    tenant_databases = existing_databases.select do |db_name|
      !%w[information_schema performance_schema mysql sys ai_resume_parser_development ai_resume_parser_test].include?(db_name)
    end
    
    puts "📊 Found #{tenant_databases.length} tenant databases: #{tenant_databases.join(', ')}"
    
    if tenant_databases.empty?
      puts "⚠️  No tenant databases found. Skipping tenant migrations."
      return
    end
    
    # Migrate each existing tenant database
    tenant_databases.each do |tenant_name|
      begin
        puts "🔄 Migrating tenant: #{tenant_name}"
        Apartment::Tenant.switch(tenant_name) do
          ActiveRecord::Migrator.migrate(Rails.root.join('db', 'migrate'))
        end
        puts "✅ Successfully migrated tenant: #{tenant_name}"
      rescue => e
        puts "❌ Failed to migrate tenant #{tenant_name}: #{e.message}"
        # Continue with other tenants
      end
    end
    
    puts "🎉 Tenant migration completed!"
  end
end
