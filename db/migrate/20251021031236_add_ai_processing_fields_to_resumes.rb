class AddAiProcessingFieldsToResumes < ActiveRecord::Migration[8.0]
  def change
    add_column :resumes, :processing_status, :integer, default: 0 # pending, queued, processing, completed, failed
    add_column :resumes, :processing_started_at, :datetime
    add_column :resumes, :processing_completed_at, :datetime
    add_column :resumes, :processing_error, :text
    add_column :resumes, :ai_provider_used, :string
    
    # Extracted data fields
    add_column :resumes, :extracted_name, :string
    add_column :resumes, :extracted_email, :string
    add_column :resumes, :extracted_phone, :string
    add_column :resumes, :extracted_location, :string
    add_column :resumes, :extracted_summary, :text
    add_column :resumes, :extracted_skills, :text # JSON
    add_column :resumes, :extracted_experience, :text # JSON
    add_column :resumes, :extracted_education, :text # JSON
    add_column :resumes, :extracted_text, :text # Raw extracted text
    add_column :resumes, :extraction_confidence, :decimal, precision: 5, scale: 2
    
    # Add index for processing status queries
    add_index :resumes, :processing_status
    add_index :resumes, [:processing_status, :created_at]
  end
end
