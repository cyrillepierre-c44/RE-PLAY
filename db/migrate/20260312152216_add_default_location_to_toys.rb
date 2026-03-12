class AddDefaultLocationToToys < ActiveRecord::Migration[8.1]
  def change
    change_column_default :toys, :location, from: nil, to: "En attente de validation"
  end
end
