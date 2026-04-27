class RemoveWeightFromBoxes < ActiveRecord::Migration[8.1]
  def change
    remove_column :boxes, :weight, :decimal
  end
end
