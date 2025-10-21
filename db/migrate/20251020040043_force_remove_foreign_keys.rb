class ForceRemoveForeignKeys < ActiveRecord::Migration[8.0]
  def up
    # Force remove foreign keys using raw SQL
    execute "ALTER TABLE resumes DROP CONSTRAINT IF EXISTS fk_rails_867611551d"
    execute "ALTER TABLE job_descriptions DROP CONSTRAINT IF EXISTS fk_rails_user_job_desc"  
    execute "ALTER TABLE resume_processings DROP CONSTRAINT IF EXISTS fk_rails_user_processing"
    
    puts "✅ Force removed all cross-schema foreign key constraints"
  end

  def down
    # Don't re-add - they break multi-tenancy
    puts "⚠️ Not re-adding foreign keys (would break multi-tenancy)"
  end
end