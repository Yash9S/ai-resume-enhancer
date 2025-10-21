# spec/factories/resumes.rb
FactoryBot.define do
  factory :resume do
    title { "Sample Resume #{SecureRandom.hex(4)}" }
    status { :uploaded }
    processing_status { :pending }
    user

    trait :with_file do
      after(:build) do |resume|
        resume.file.attach(
          io: StringIO.new("%PDF-1.4\n1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>\nendobj\nxref\n0 4\n0000000000 65535 f \n0000000009 00000 n \n0000000058 00000 n \n0000000115 00000 n \ntrailer\n<< /Size 4 /Root 1 0 R >>\nstartxref\n181\n%%EOF"),
          filename: 'sample_resume.pdf',
          content_type: 'application/pdf'
        )
      end
    end

    trait :with_docx_file do
      after(:build) do |resume|
        resume.file.attach(
          io: StringIO.new("PK\x03\x04fake docx content"),
          filename: 'sample_resume.docx',
          content_type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
        )
      end
    end

    trait :with_ai_data do
      processing_status { :completed }
      status { :processed }
      extracted_name { 'John Doe' }
      extracted_email { 'john.doe@example.com' }
      extracted_phone { '+1-555-123-4567' }
      extracted_location { 'San Francisco, CA' }
      extracted_summary { 'Experienced software engineer with 5+ years of experience' }
      extracted_skills { '["Ruby", "JavaScript", "Python", "Rails", "React", "PostgreSQL"]' }
      extracted_experience do
        '[
          {
            "company": "TechCorp Inc",
            "position": "Senior Software Engineer",
            "duration": "2020-Present",
            "description": "Led development team for microservices architecture"
          },
          {
            "company": "StartupXYZ",
            "position": "Full Stack Developer",
            "duration": "2018-2020",
            "description": "Built web applications using Ruby on Rails and React"
          }
        ]'
      end
      extracted_education do
        '[
          {
            "degree": "Bachelor of Science in Computer Science",
            "institution": "University of California",
            "year": "2018"
          }
        ]'
      end
      extraction_confidence { 0.92 }
      processing_started_at { 2.minutes.ago }
      processing_completed_at { 1.minute.ago }
    end

    trait :processing do
      status { :processing }
      processing_status { :processing }
      processing_started_at { 30.seconds.ago }
    end

    trait :failed do
      status { :failed }
      processing_status { :failed }
      processing_error { 'AI service unavailable' }
      processing_started_at { 5.minutes.ago }
    end

    trait :queued do
      status { :uploaded }
      processing_status { :queued }
    end

    trait :minimal_ai_data do
      processing_status { :completed }
      status { :processed }
      extracted_name { 'Jane Smith' }
      extracted_email { 'jane@example.com' }
    end

    trait :with_job_description do
      association :job_description
    end

    trait :large_skills_set do
      after(:build) do |resume|
        skills = [
          "Ruby", "Ruby on Rails", "JavaScript", "TypeScript", "Python", "Java",
          "React", "Vue.js", "Angular", "Node.js", "Express.js", "PostgreSQL",
          "MySQL", "MongoDB", "Redis", "Docker", "Kubernetes", "AWS", "Azure",
          "Git", "GitHub", "GitLab", "CI/CD", "Jenkins", "HTML", "CSS", "SCSS",
          "Bootstrap", "Tailwind CSS", "RESTful APIs", "GraphQL", "Microservices"
        ]
        resume.extracted_skills = skills.to_json
      end
    end

    trait :complex_experience do
      after(:build) do |resume|
        experience = [
          {
            "company": "Meta Platforms Inc",
            "position": "Senior Software Engineer",
            "duration": "2021-Present",
            "description": "Lead backend development for user engagement platform serving 100M+ users. Designed and implemented microservices architecture using Ruby on Rails and PostgreSQL. Mentored junior developers and conducted technical interviews.",
            "technologies": ["Ruby", "Rails", "PostgreSQL", "Redis", "Docker", "Kubernetes"],
            "achievements": [
              "Reduced API response time by 40%",
              "Implemented caching strategy that improved system performance",
              "Led migration from monolith to microservices"
            ]
          },
          {
            "company": "Shopify Inc",
            "position": "Software Engineer",
            "duration": "2019-2021",
            "description": "Developed e-commerce features for merchant dashboard. Built RESTful APIs and integrated with third-party payment processors. Collaborated with product and design teams to deliver user-centric solutions.",
            "technologies": ["Ruby", "Rails", "JavaScript", "React", "MySQL"],
            "achievements": [
              "Shipped 15+ features affecting 1M+ merchants",
              "Optimized database queries reducing load time by 60%",
              "Implemented automated testing suite"
            ]
          },
          {
            "company": "StartupXYZ",
            "position": "Full Stack Developer",
            "duration": "2017-2019",
            "description": "Built web application from scratch using Ruby on Rails and React. Responsible for both frontend and backend development, database design, and deployment infrastructure.",
            "technologies": ["Ruby", "Rails", "React", "PostgreSQL", "AWS"],
            "achievements": [
              "Launched MVP in 6 months",
              "Grew user base from 0 to 10,000 users",
              "Maintained 99.9% uptime"
            ]
          }
        ]
        resume.extracted_experience = experience.to_json
      end
    end

    trait :advanced_education do
      after(:build) do |resume|
        education = [
          {
            "degree": "Master of Science in Computer Science",
            "institution": "Stanford University",
            "year": "2017",
            "gpa": "3.8/4.0",
            "coursework": [
              "Advanced Algorithms",
              "Distributed Systems", 
              "Machine Learning",
              "Database Systems"
            ],
            "thesis": "Optimizing Database Performance in Distributed Systems"
          },
          {
            "degree": "Bachelor of Science in Computer Science",
            "institution": "University of California, Berkeley",
            "year": "2015",
            "gpa": "3.6/4.0",
            "honors": "Magna Cum Laude",
            "activities": [
              "Computer Science Student Association Vice President",
              "Teaching Assistant for Data Structures course"
            ]
          }
        ]
        resume.extracted_education = education.to_json
      end
    end

    # Trait for testing JSON parsing errors
    trait :corrupted_json do
      extracted_skills { 'invalid json format {' }
      extracted_experience { '[{"company": "incomplete' }
      extracted_education { 'not json at all' }
    end

    # Trait for testing timeout scenarios
    trait :timeout_scenario do
      processing_status { :processing }
      processing_started_at { 10.minutes.ago }
      processing_error { nil }
    end

    # Trait for testing confidence scores
    trait :high_confidence do
      extraction_confidence { 0.95 }
    end

    trait :low_confidence do
      extraction_confidence { 0.45 }
    end

    trait :medium_confidence do
      extraction_confidence { 0.72 }
    end

    # Trait for specific user assignment
    trait :for_user do
      transient do
        target_user { nil }
      end

      after(:build) do |resume, evaluator|
        resume.user = evaluator.target_user if evaluator.target_user
      end
    end

    # Legacy compatibility
    trait :with_content do
      extracted_name { 'John Doe' }
      extracted_email { 'john@example.com' }
      extracted_summary { 'Software engineer with experience in web development' }
    end

    trait :processed do
      with_ai_data
    end
  end
end