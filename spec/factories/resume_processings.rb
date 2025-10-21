# spec/factories/resume_processings.rb
FactoryBot.define do
  factory :resume_processing do
    association :resume
    association :job_description
    
    trait :with_analysis do
      analysis { {
        "match_score" => 85,
        "matching_skills" => ["Ruby on Rails", "JavaScript", "PostgreSQL"],
        "missing_skills" => ["AWS", "Docker"],
        "experience_match" => "Strong match for software development experience",
        "recommendations" => [
          "Highlight your Ruby on Rails experience more prominently",
          "Consider adding cloud platform experience",
          "Emphasize collaborative work experience"
        ]
      }.to_json }
    end

    trait :high_match do
      analysis { {
        "match_score" => 92,
        "matching_skills" => ["Ruby on Rails", "JavaScript", "PostgreSQL", "Git", "Agile"],
        "missing_skills" => ["AWS"],
        "experience_match" => "Excellent match for all core requirements",
        "recommendations" => [
          "Perfect candidate profile",
          "Consider highlighting leadership experience"
        ]
      }.to_json }
    end

    trait :low_match do
      analysis { {
        "match_score" => 45,
        "matching_skills" => ["JavaScript"],
        "missing_skills" => ["Ruby on Rails", "PostgreSQL", "Git", "AWS", "Docker"],
        "experience_match" => "Limited match for required experience",
        "recommendations" => [
          "Gain experience with Ruby on Rails framework",
          "Learn database management with PostgreSQL",
          "Develop version control skills with Git"
        ]
      }.to_json }
    end
  end
end