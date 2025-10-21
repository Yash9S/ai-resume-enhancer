class CreateTenants < ActiveRecord::Migration[8.0]
  def change
    create_table :tenants do |t|
      t.string :name, null: false
      t.string :subdomain, null: false
      t.string :schema_name, null: false
      t.string :status, default: 'active'
      t.text :description

      t.timestamps
    end

    add_index :tenants, :subdomain, unique: true
    add_index :tenants, :schema_name, unique: true
    add_index :tenants, :status
  end
end
