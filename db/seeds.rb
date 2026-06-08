puts "Cleaning database..."

Box.destroy_all
Category.destroy_all
Action.destroy_all
Toy.destroy_all
puts "Creating seeds..."

# Create categories from the list
categories = [
  { name: "Poupons, Barbies, Bratz, têtes à coiffer, accessoires", icon: "fa-child-dress" },
  { name: "Véhicules, circuits, garages",                          icon: "fa-car" },
  { name: "Lego & Playmobil",                                      icon: "fa-cubes" },
  { name: "Livres 0 - 6 ans",                                      icon: "fa-book" },
  { name: "Livres 7 - 10 ans",                                     icon: "fa-book-open" },
  { name: "Livres, mangas, BD 11 ans et +",                        icon: "fa-book-bookmark" },
  { name: "Jeux de société 0 à 6 ans",                             icon: "fa-dice" },
  { name: "Jeux de société 7 à 11 ans",                            icon: "fa-dice-five" },
  { name: "Jeux de société 12 ans et +",                           icon: "fa-chess" },
  { name: "Puzzle et loisirs créatifs",                            icon: "fa-puzzle-piece" },
  { name: "Peluches et doudous",                                   icon: "fa-hippo" },
  { name: "Jeux d'extérieur",                                      icon: "fa-futbol" },
  { name: "Jouet premier âge",                                     icon: "fa-baby" },
  { name: "Jeux de construction",                                  icon: "fa-hammer" },
  { name: "Figurines et mini monde",                               icon: "fa-chess-pawn" },
  { name: "Imitation",                                             icon: "fa-masks-theater" },
  { name: "Déguisements",                                          icon: "fa-hat-wizard" }
]

categories.each do |attrs|
  Category.create!(attrs)
end

puts "#{Category.count} categories created!"

# Create a sample box and toy
playmobil = Category.find_by(name: "Lego & Playmobil")
box = Box.create!(category: playmobil, electronic: false, weight: 1.5)
puts "Box created!"

Toy.create!(barcode: "tata", box: box, category: playmobil, clean: true, complete: true, playable: true)
puts "Toy created!"

puts "Seeding completed!"
