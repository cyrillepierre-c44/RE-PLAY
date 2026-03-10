class AddLocationToToys < ActiveRecord::Migration[8.1]
  def change
    add_column :toys, :location, :string
  end
end
