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
