# Sample data for tenant schemas
puts "🌱 Creating sample data for tenant schemas..."

# Create sample data for each active tenant
Tenant.active.each do |tenant|
  puts "Seeding tenant: #{tenant.name} (#{tenant.schema_name})"
  
  Apartment::Tenant.switch!(tenant.schema_name) do
    # Create a sample user for this tenant (if not exists)
    user = User.find_or_create_by(email: "user@#{tenant.subdomain}.com") do |u|
      u.password = 'password123'
      u.password_confirmation = 'password123'
      u.role = :user
    end
    
    if user.persisted?
      # Create sample job descriptions
      jd1 = user.job_descriptions.find_or_create_by(title: 'Senior Software Engineer') do |jd|
        jd.company_name = tenant.name
        jd.location = 'Remote'
        jd.content = 'Looking for experienced software engineer with Rails expertise.'
      end
      
      jd2 = user.job_descriptions.find_or_create_by(title: 'Product Manager') do |jd|
        jd.company_name = tenant.name
        jd.location = 'New York, NY'
        jd.content = 'Seeking product manager to lead our AI initiatives.'
      end
      
      # Create sample resumes
      resume1 = user.resumes.find_or_create_by(original_filename: 'john_doe_resume.pdf') do |r|
        r.status = 'processed'
        r.extracted_text = 'John Doe - Senior Software Engineer with 5 years experience in Ruby on Rails...'
      end
      
      resume2 = user.resumes.find_or_create_by(original_filename: 'jane_smith_resume.pdf') do |r|
        r.status = 'processing'
        r.extracted_text = 'Jane Smith - Product Manager with experience in AI and ML products...'
      end
      
      resume3 = user.resumes.find_or_create_by(original_filename: 'failed_resume.pdf') do |r|
        r.status = 'failed'
        r.extracted_text = nil
      end
      
      # Create sample resume processings
      if resume1.persisted? && jd1.persisted?
        ResumeProcessing.find_or_create_by(resume: resume1, job_description: jd1) do |rp|
          rp.status = 'completed'
          rp.match_score = 85.5
          rp.enhanced_content = 'Enhanced resume content for John Doe matching Software Engineer role...'
        end
      end
      
      if resume2.persisted? && jd2.persisted?
        ResumeProcessing.find_or_create_by(resume: resume2, job_description: jd2) do |rp|
          rp.status = 'processing'
          rp.match_score = nil
        end
      end
      
      if resume3.persisted? && jd1.persisted?
        ResumeProcessing.find_or_create_by(resume: resume3, job_description: jd1) do |rp|
          rp.status = 'failed'
          rp.match_score = nil
        end
      end
      
      puts "  ✅ Created sample data for #{tenant.name}"
    end
  end
rescue => e
  puts "  ❌ Error seeding #{tenant.name}: #{e.message}"
end

puts "🌱 Tenant seeding completed!"