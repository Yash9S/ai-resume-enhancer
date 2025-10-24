class AddRawTextToResumes < ActiveRecord::Migration[8.0]
  def change
    add_column :resumes, :raw_text, :text
  end
end
