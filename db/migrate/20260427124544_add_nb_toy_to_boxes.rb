class AddNbToyToBoxes < ActiveRecord::Migration[8.1]
  def change
    add_column :boxes, :nb_toys, :integer
  end
end
