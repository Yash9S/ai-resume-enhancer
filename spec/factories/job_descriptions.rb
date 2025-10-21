# spec/factories/job_descriptions.rb
FactoryBot.define do
  factory :job_description do
    association :user
    title { Faker::Job.title }
    company { Faker::Company.name }
    content { "We are looking for a skilled #{Faker::Job.title} to join our team.\n\nResponsibilities:\n- #{Faker::Lorem.sentence}\n- #{Faker::Lorem.sentence}\n- #{Faker::Lorem.sentence}\n\nRequirements:\n- #{Faker::Lorem.sentence}\n- #{Faker::Lorem.sentence}\n- #{Faker::Lorem.sentence}\n\nSkills:\n- #{Faker::Job.key_skill}\n- #{Faker::Job.key_skill}\n- #{Faker::Job.key_skill}" }

    trait :software_engineer do
      title { "Software Engineer" }
      company { "Tech Solutions Inc." }
      content { "We are seeking a talented Software Engineer to join our development team.\n\nResponsibilities:\n- Design and develop web applications using modern frameworks\n- Collaborate with product managers and designers\n- Write clean, maintainable, and efficient code\n- Participate in code reviews and technical discussions\n- Troubleshoot and debug applications\n\nRequirements:\n- Bachelor's degree in Computer Science or related field\n- 3+ years of experience in software development\n- Strong problem-solving skills\n- Experience with agile development methodologies\n\nTechnical Skills:\n- Proficiency in Ruby on Rails\n- Experience with JavaScript and modern JS frameworks\n- Knowledge of database design and SQL\n- Familiarity with version control systems (Git)\n- Understanding of web technologies (HTML, CSS, REST APIs)\n- Experience with cloud platforms (AWS, Azure, GCP)" }
    end

    trait :data_scientist do
      title { "Data Scientist" }
      company { "Analytics Corp" }
      content { "Join our data team as a Data Scientist to drive insights and innovation.\n\nResponsibilities:\n- Analyze large datasets to extract meaningful insights\n- Build predictive models and machine learning algorithms\n- Create data visualizations and reports\n- Collaborate with stakeholders to define requirements\n\nRequirements:\n- Master's degree in Data Science, Statistics, or related field\n- 5+ years of experience in data analysis\n- Strong statistical and mathematical background\n\nTechnical Skills:\n- Python, R, SQL\n- Machine Learning frameworks (scikit-learn, TensorFlow)\n- Data visualization tools (Tableau, Power BI)\n- Big data technologies (Spark, Hadoop)" }
    end
  end
end