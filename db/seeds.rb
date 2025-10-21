# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create admin user for development
if Rails.env.development?
  admin_user = User.find_or_create_by(email: 'admin@airesume.com') do |user|
    user.password = 'password123'
    user.password_confirmation = 'password123'
    user.role = :admin
  end
  
  puts "✅ Created admin user: #{admin_user.email}" if admin_user.persisted?
  
  # Create sample regular user
  sample_user = User.find_or_create_by(email: 'user@example.com') do |user|
    user.password = 'password123'
    user.password_confirmation = 'password123'
    user.role = :user
  end
  
  puts "✅ Created sample user: #{sample_user.email}" if sample_user.persisted?
  
  # Create sample tenants for multi-tenancy
  sample_tenants = [
    { name: 'Acme Corporation', subdomain: 'acme', status: 'active' },
    { name: 'TechStart Inc', subdomain: 'techstart', status: 'active' },
    { name: 'Global Solutions', subdomain: 'globalsol', status: 'active' },
    { name: 'Innovation Labs', subdomain: 'innovlabs', status: 'pending' }
  ]
  
  sample_tenants.each do |tenant_data|
    tenant = Tenant.find_or_create_by(subdomain: tenant_data[:subdomain]) do |t|
      t.name = tenant_data[:name]
      t.status = tenant_data[:status]
    end
    puts "✅ Created tenant: #{tenant.name} (#{tenant.subdomain}.airesumeparser.com)" if tenant.persisted?
  end
  
  # Create sample job description
  if sample_user.persisted?
    job_desc = sample_user.job_descriptions.find_or_create_by(title: 'Software Engineer - Full Stack') do |jd|
      jd.company_name = 'Tech Corp'
      jd.location = 'San Francisco, CA'
      jd.content = <<~JD
        We are looking for a talented Full Stack Software Engineer to join our team.
        
        Requirements:
        - 3+ years of experience in web development
        - Proficiency in Ruby on Rails
        - Experience with JavaScript, React, or Vue.js
        - Knowledge of PostgreSQL or MySQL
        - Experience with Git and version control
        - Strong problem-solving skills
        - Bachelor's degree in Computer Science or equivalent
        
        Responsibilities:
        - Develop and maintain web applications
        - Collaborate with cross-functional teams
        - Write clean, maintainable code
        - Participate in code reviews
        - Troubleshoot and debug applications
        
        Nice to have:
        - Experience with Docker and containerization
        - Knowledge of AWS or cloud platforms
        - Experience with AI/ML integration
      JD
    end
    
    puts "✅ Created sample job description: #{job_desc.title}" if job_desc.persisted?
  end
end

puts "🌱 Database seeding completed!"
