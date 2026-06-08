class AddIconToCategories < ActiveRecord::Migration[8.1]
  ICONS = {
    "Poupons, Barbies, Bratz, têtes à coiffer, accessoires" => "fa-child-dress",
    "Véhicules, circuits, garages"                          => "fa-car",
    "Lego & Playmobil"                                      => "fa-cubes",
    "Livres 0 - 6 ans"                                      => "fa-book",
    "Livres 7 - 10 ans"                                     => "fa-book-open",
    "Livres, mangas, BD 11 ans et +"                        => "fa-book-bookmark",
    "Jeux de société 0 à 6 ans"                             => "fa-dice",
    "Jeux de société 7 à 11 ans"                            => "fa-dice-five",
    "Jeux de société 12 ans et +"                           => "fa-chess",
    "Puzzle et loisirs créatifs"                            => "fa-puzzle-piece",
    "Peluches et doudous"                                   => "fa-hippo",
    "Jeux d'extérieur"                                      => "fa-futbol",
    "Jouet premier âge"                                     => "fa-baby",
    "Jeux de construction"                                  => "fa-hammer",
    "Figurines et mini monde"                               => "fa-chess-pawn",
    "Imitation"                                             => "fa-masks-theater",
    "Déguisements"                                          => "fa-hat-wizard"
  }.freeze

  def up
    add_column :categories, :icon, :string, default: "fa-tag"
    ICONS.each do |name, icon|
      execute "UPDATE categories SET icon = #{quote(icon)} WHERE name = #{quote(name)}"
    end
  end

  def down
    remove_column :categories, :icon
  end
end
