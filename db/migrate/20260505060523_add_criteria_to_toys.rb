class AddCriteriaToToys < ActiveRecord::Migration[8.1]
  def change
    add_column :toys, :french, :boolean, default: false
    add_column :toys, :ce_mark, :boolean, default: false
    add_column :toys, :safe, :boolean, default: false
  end
end
