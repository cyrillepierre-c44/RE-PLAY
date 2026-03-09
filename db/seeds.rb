
User.destroy_all
Box.destroy_all
Category.destroy_all
Action.destroy_all



user = User.create!(email: "toto@gmail.com", password: "password")
playmobil = Category.create!(name: "Playmobil")
box = Box.create!(category: playmobil)

Action.create!(actionable: box, content: "toto a pesé la boite", user: user)
