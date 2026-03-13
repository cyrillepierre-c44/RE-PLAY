class AddStatusToToys < ActiveRecord::Migration[8.1]
  def change
    add_column :toys, :status, :string, default: "pending", null: false
  end
end
