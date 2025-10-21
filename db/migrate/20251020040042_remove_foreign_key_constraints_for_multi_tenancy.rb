class RemoveForeignKeyConstraintsForMultiTenancy < ActiveRecord::Migration[8.0]
  def up
    # Remove foreign key constraints that don't work with multi-tenancy
    # Users are in public schema, but resumes/jobs/processings are in tenant schemas
    
    # Remove foreign keys from tenant-scoped models to public schema models
    remove_foreign_key :resumes, :users if foreign_key_exists?(:resumes, :users)
    remove_foreign_key :job_descriptions, :users if foreign_key_exists?(:job_descriptions, :users)
    remove_foreign_key :resume_processings, :users if foreign_key_exists?(:resume_processings, :users)
    
    puts "✅ Removed cross-schema foreign key constraints for multi-tenancy"
  end

  def down
    # Re-add foreign keys if we need to rollback
    add_foreign_key :resumes, :users unless foreign_key_exists?(:resumes, :users)
    add_foreign_key :job_descriptions, :users unless foreign_key_exists?(:job_descriptions, :users)
    add_foreign_key :resume_processings, :users unless foreign_key_exists?(:resume_processings, :users)
    
    puts "⚠️ Re-added foreign key constraints (multi-tenancy will break)"
  end
end
