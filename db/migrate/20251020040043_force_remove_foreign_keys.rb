class ForceRemoveForeignKeys < ActiveRecord::Migration[8.0]
  def up
    # Force remove foreign keys using MySQL syntax
    # Check if constraints exist and remove them safely
    
    # Get current adapter to handle both PostgreSQL and MySQL
    if ActiveRecord::Base.connection.adapter_name.downcase.include?('mysql')
      # MySQL syntax for dropping foreign keys
      begin
        execute "ALTER TABLE resumes DROP FOREIGN KEY fk_rails_867611551d" 
      rescue ActiveRecord::StatementInvalid => e
        puts "Foreign key fk_rails_867611551d doesn't exist or already removed: #{e.message}"
      end
      
      begin
        execute "ALTER TABLE job_descriptions DROP FOREIGN KEY fk_rails_user_job_desc"
      rescue ActiveRecord::StatementInvalid => e
        puts "Foreign key fk_rails_user_job_desc doesn't exist or already removed: #{e.message}"
      end
      
      begin
        execute "ALTER TABLE resume_processings DROP FOREIGN KEY fk_rails_user_processing"
      rescue ActiveRecord::StatementInvalid => e
        puts "Foreign key fk_rails_user_processing doesn't exist or already removed: #{e.message}"
      end
      
    else
      # PostgreSQL syntax
      execute "ALTER TABLE resumes DROP CONSTRAINT IF EXISTS fk_rails_867611551d"
      execute "ALTER TABLE job_descriptions DROP CONSTRAINT IF EXISTS fk_rails_user_job_desc"  
      execute "ALTER TABLE resume_processings DROP CONSTRAINT IF EXISTS fk_rails_user_processing"
    end
    
    puts "✅ Force removed all cross-schema foreign key constraints"
  end

  def down
    # Don't re-add - they break multi-tenancy
    puts "⚠️ Not re-adding foreign keys (would break multi-tenancy)"
  end
end