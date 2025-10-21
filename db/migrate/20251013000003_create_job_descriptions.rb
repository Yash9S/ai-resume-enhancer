class CreateJobDescriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :job_descriptions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.text :content, null: false
      t.string :company_name
      t.string :location
      t.json :extracted_keywords
      t.json :requirements

      t.timestamps
    end

    add_index :job_descriptions, :created_at
  end
end