# Catégorie « Grosses pièces » : une caisse (un roll de 2 m) qui mélange des
# jouets encombrants de catégories différentes. `mixed` marque ce type de
# catégorie : elle sert aux caisses, jamais aux jouets — un jouet créé depuis
# une telle caisse n'hérite donc d'aucune catégorie (d'où category_id nullable,
# le temps que l'opérateur choisisse la vraie catégorie du jouet).
class AddMixedToCategories < ActiveRecord::Migration[8.1]
  NAME = "Grosses pièces".freeze
  ICON = "fa-dolly".freeze

  def up
    add_column :categories, :mixed, :boolean, default: false, null: false
    change_column_null :toys, :category_id, true
    execute <<~SQL.squish
      INSERT INTO categories (name, icon, mixed, created_at, updated_at)
      SELECT #{quote(NAME)}, #{quote(ICON)}, TRUE, NOW(), NOW()
      WHERE NOT EXISTS (SELECT 1 FROM categories WHERE name = #{quote(NAME)})
    SQL
    execute "UPDATE categories SET mixed = TRUE WHERE name = #{quote(NAME)}"
  end

  def down
    # Les caisses « Grosses pièces » et leurs jouets sans catégorie empêchent
    # un retour arrière automatique : on ne supprime que la colonne.
    remove_column :categories, :mixed
  end
end
