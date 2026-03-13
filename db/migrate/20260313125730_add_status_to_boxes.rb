class AddStatusToBoxes < ActiveRecord::Migration[8.1]
  def change
    add_column :boxes, :status, :string, défault: "pending", null: false
  end
end
