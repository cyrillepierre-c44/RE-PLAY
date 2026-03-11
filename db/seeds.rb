puts "Cleaning database..."

Box.destroy_all
Category.destroy_all
Action.destroy_all
Toy.destroy_all
puts "Creating seeds..."

playmobil = Category.create!(name: "Playmobil")
box = Box.create!(category: playmobil)

puts "Box created!"

Toy.create!(barcode: "tata", box: box, category: playmobil)
puts "Toy created!"



"Poupons, Barbies, Bratz, têtes à coiffer, accessoires"

"Véhicules, circuits, garages"

"Lego & Playmobil"

"Livres 0 - 6 ans"

"Livres 7 - 10 ans"

"Livres, mangas, BD 11 ans et +"

"Jeux de société 0 à 6 ans"

"Jeux de société 7 à 11 ans"

"Jeux de société 12 ans et +"

"Puzzle et loisirs créatifs"

"Peluches et doudous"

"Jeux d'extérieur"

"Jouet premier âge"

"Jeux de construction"

"Figurines et mini monde"

"Imitation"

"Déguisements"
