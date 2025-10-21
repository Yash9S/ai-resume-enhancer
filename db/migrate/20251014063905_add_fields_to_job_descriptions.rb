class AddFieldsToJobDescriptions < ActiveRecord::Migration[8.0]
  def change
    add_column :job_descriptions, :employment_type, :string
    add_column :job_descriptions, :experience_level, :string
    add_column :job_descriptions, :salary_range, :string
    add_column :job_descriptions, :required_skills, :text
    add_column :job_descriptions, :company, :string
    add_column :job_descriptions, :description, :text
  end
end
