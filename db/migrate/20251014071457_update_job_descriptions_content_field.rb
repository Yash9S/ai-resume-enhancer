class UpdateJobDescriptionsContentField < ActiveRecord::Migration[8.0]
  def up
    # Make content nullable
    change_column_null :job_descriptions, :content, true
    
    # Copy description to content for existing records
    execute <<-SQL
      UPDATE job_descriptions 
      SET content = description 
      WHERE description IS NOT NULL AND content IS NULL;
    SQL
    
    # Set content = description for future compatibility
    execute <<-SQL
      UPDATE job_descriptions 
      SET content = COALESCE(description, content, title) 
      WHERE content IS NULL;
    SQL
  end

  def down
    # Revert content back to not null (only if all records have content)
    change_column_null :job_descriptions, :content, false
  end
end
