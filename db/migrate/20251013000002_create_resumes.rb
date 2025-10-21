class CreateResumes < ActiveRecord::Migration[8.0]
  def change
    create_table :resumes do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.text :original_content
      t.text :extracted_content
      t.text :enhanced_content
      t.integer :status, default: 0, null: false
      t.json :extracted_data

      t.timestamps
    end

    add_index :resumes, :status
    add_index :resumes, :created_at
  end
end