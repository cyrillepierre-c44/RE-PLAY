# Seuil de fiabilité : en dessous de `min_sample` jouets contrôlés, le tableau de
# bord n'affiche pas de pourcentage (un refus sur 10 jouets ferait 90 %, ce qui
# ne permet de juger ni un opérateur ni une journée).
class AddMinSampleToQualitySettings < ActiveRecord::Migration[8.1]
  def change
    add_column :quality_settings, :min_sample, :integer, null: false, default: 20
  end
end
