#!/usr/bin/env ruby

# Create tenant schemas with proper tables
puts "🏢 Creating tenant schemas with tables..."

Tenant.active.each do |tenant|
  puts "Creating tenant: #{tenant.name} (#{tenant.schema_name})"
  
  begin
    # Create the schema with tables
    Apartment::Tenant.create(tenant.schema_name)
    puts "  ✅ Created #{tenant.schema_name} with tables"
  rescue => e
    puts "  ❌ Error creating #{tenant.schema_name}: #{e.message}"
  end
end

puts "🏢 Tenant schema creation completed!"