class AddMissingIndexes < ActiveRecord::Migration[8.1]
  def change
    # Colonnes filtrées par les scopes (waiting/validated/deleted, sold…)
    # et par le dashboard — sans index, scan complet dès quelques milliers
    # de lignes.
    add_index :toys, :status
    add_index :toys, :sold
    add_index :toys, :price
    add_index :toys, :created_at
    add_index :boxes, :status
    add_index :boxes, :created_at
    add_index :actions, :created_at
  end
end
