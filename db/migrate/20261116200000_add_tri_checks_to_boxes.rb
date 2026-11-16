# Vérifications du TRI cochées par la personne qui crée la caisse (clés de
# QualityCause::TRI_CHECKS). Une caisse ne peut être enregistrée que toutes
# cochées : c'est l'équivalent, pour le TRI, des six critères du valoriste.
class AddTriChecksToBoxes < ActiveRecord::Migration[8.1]
  def change
    add_column :boxes, :tri_checks, :string, array: true, null: false, default: []
  end
end
