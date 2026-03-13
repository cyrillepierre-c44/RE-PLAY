puts "Cleaning database..."

Box.destroy_all
Category.destroy_all
Action.destroy_all
Toy.destroy_all
puts "Creating seeds..."

# Create categories from the list
categories = [
  "Poupons, Barbies, Bratz, têtes à coiffer, accessoires",
  "Véhicules, circuits, garages",
  "Lego & Playmobil",
  "Livres 0 - 6 ans",
  "Livres 7 - 10 ans",
  "Livres, mangas, BD 11 ans et +",
  "Jeux de société 0 à 6 ans",
  "Jeux de société 7 à 11 ans",
  "Jeux de société 12 ans et +",
  "Puzzle et loisirs créatifs",
  "Peluches et doudous",
  "Jeux d'extérieur",
  "Jouet premier âge",
  "Jeux de construction",
  "Figurines et mini monde",
  "Imitation",
  "Déguisements"
]

categories.each do |name|
  Category.create!(name: )
end

puts "#{Category.count} categories created!"

# Create a sample box and toy
playmobil = Category.find_by(name: "Lego & Playmobil")
box = Box.create!(category: playmobil, electronic: false, weight: 1.5)
puts "Box created!"

Toy.create!(barcode: "tata", box: box, category: playmobil, clean: true, complete: true, playable: true)
puts "Toy created!"

puts "Seeding completed!"
