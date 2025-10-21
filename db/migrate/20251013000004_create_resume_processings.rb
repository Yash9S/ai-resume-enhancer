class CreateResumeProcessings < ActiveRecord::Migration[8.0]
  def change
    create_table :resume_processings do |t|
      t.references :resume, null: false, foreign_key: true
      t.references :job_description, null: true, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :processing_type, null: false
      t.integer :status, default: 0, null: false
      t.text :result
      t.text :error_message
      t.json :ai_response
      t.datetime :started_at
      t.datetime :completed_at
      t.float :match_score

      t.timestamps
    end

    add_index :resume_processings, :processing_type
    add_index :resume_processings, :status
    add_index :resume_processings, :created_at
  end
end