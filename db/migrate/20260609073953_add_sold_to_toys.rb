class AddSoldToToys < ActiveRecord::Migration[8.1]
  def change
    add_column :toys, :sold, :boolean, default: false, null: false
  end
end
