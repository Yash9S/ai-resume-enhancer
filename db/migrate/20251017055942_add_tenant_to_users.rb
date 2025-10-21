class AddTenantToUsers < ActiveRecord::Migration[8.0]
  def change
    add_reference :users, :tenant, null: true, foreign_key: true, index: true
  end
end
