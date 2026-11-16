# rubocop:disable Layout/LineLength -- jeu de données de démonstration : des phrases complètes, lisibles d'un bloc
# Base de démonstration des procédures (/procedures) : comptes et jouets
# fictifs, pour refaire les captures d'écran sans montrer de vraies données.
# Tout se lance avec `bin/procedures-captures` (voir ce script).
namespace :procedures do
  desc "Remplit la base de démonstration (refusé hors d'une base dont le nom finit par _demo)"
  task seed_demo: :environment do
    db = ActiveRecord::Base.connection.current_database
    abort "Refusé : #{db} n'est pas une base de démonstration (_demo)." unless db.end_with?("_demo")

    rng = Random.new(2026)
    now = Time.current
    photo_dir = Rails.root.join("lib/demo/photos")
    password = "demo-re-play"
    # n jours ouvrés en arrière, vers 10 h
    days_ago = lambda do |n|
      date = now.in_time_zone(WorkingDays::ZONE).to_date
      n.times do
        date -= 1
        date -= 1 while date.saturday? || date.sunday?
      end
      Time.find_zone(WorkingDays::ZONE).local(date.year, date.month, date.day, 10, 15)
    end

    [QualityCheck, Action, Toy, Box, Category, QualitySetting, User].each(&:delete_all)
    ActiveStorage::Attachment.delete_all
    ActiveStorage::Blob.delete_all
    ActiveRecord::Base.connection.execute("ALTER SEQUENCE toys_id_seq RESTART WITH 7300")
    ActiveRecord::Base.connection.execute("ALTER SEQUENCE boxes_id_seq RESTART WITH 710")

    { "Poupons, Barbies, Bratz, têtes à coiffer, accessoires" => "fa-child-dress", "Véhicules, circuits, garages" => "fa-car",
      "Lego & Playmobil" => "fa-cubes", "Livres 0 - 6 ans" => "fa-book", "Jeux de société 0 à 6 ans" => "fa-dice",
      "Jeux de société 7 à 11 ans" => "fa-dice-five", "Puzzle et loisirs créatifs" => "fa-puzzle-piece",
      "Peluches et doudous" => "fa-hippo", "Jeux d'extérieur" => "fa-futbol", "Jouet premier âge" => "fa-baby",
      "Jeux de construction" => "fa-hammer", "Figurines et mini monde" => "fa-chess-pawn", "Imitation" => "fa-masks-theater" }
      .each { |name, icon| Category.create!(name: name, icon: icon) }
    Category.create!(name: "Grosses pièces", icon: "fa-dolly", mixed: true)
    cat = ->(start) { Category.where("name LIKE ?", "#{start}%").first! }

    user = ->(name, admin: false) { User.create!(email: "#{name}@example.com", password: password, admin: admin) }
    sophie = user.call("sophie", admin: true)
    camille, nadia, karim, lucas = %w[camille nadia karim lucas].map { |name| user.call(name) }
    sorters = %w[ines theo].map { |name| user.call(name) }
    operators = [camille, nadia, karim, lucas]

    box = lambda do |category, creator, at|
      record = Box.create!(category: category, status: "pending", nb_toys: rng.rand(8..20), created_at: at, updated_at: at)
      Action.create!(user: creator, actionable: record, content: "#{creator.email} a créé la caisse C#{record.id}", created_at: at)
      record
    end
    toy = lambda do |attrs|
      photo = attrs.delete(:photo)
      at = attrs[:created_at] || now
      record = Toy.new({ french: true, ce_mark: true, safe: true, clean: true, complete: true, playable: true,
                         updated_at: at }.merge(attrs))
      record.save!(validate: false)
      record.photo.attach(io: File.open(photo_dir.join("#{photo}.jpg")), filename: "#{photo}.jpg", content_type: "image/jpeg") if photo
      Action.create!(user: record.operator, actionable: record, created_at: at,
                     content: "#{record.operator.email} a débuté la création du jouet J#{record.id}")
      record
    end
    check = lambda do |record, round, decision, at, causes: [], comment: nil, note: nil, reworked: nil, resolved: nil|
      QualityCheck.create!(toy: record, round: round, decision: decision, causes: causes, cq_comment: comment,
                           operator_comment: note, operator_id: record.operator_id, checker: sophie,
                           created_at: at, updated_at: at, reworked_at: reworked, resolved_at: resolved)
    end

    # ── Jouets mis en scène pour les captures ──────────────────────────────
    main_box = box.call(cat.call("Peluches"), sorters[0], days_ago.call(8))
    mixed_box = box.call(cat.call("Jeux de société 0"), sorters[1], days_ago.call(7))
    main_box.update_columns(nb_toys: 20)
    # caisse en cours de création par le TRI (étape « étiqueter »)
    draft_box = Box.create!(category: cat.call("Jeux de construction"), status: "draft")
    Action.create!(user: sorters[0], actionable: draft_box, content: "#{sorters[0].email} a créé la caisse C#{draft_box.id}")
    featured = {}

    featured[:late] = toy.call(box: main_box, category: cat.call("Peluches"), operator: camille, status: "review", price: 6, clean: false,
                               photo: "peluche", created_at: days_ago.call(7))
    check.call(featured[:late], 1, "refused", days_ago.call(6), causes: %w[nettoyage],
                                                                comment: "La peluche est encore tachée sous une patte.", note: "Lavée en machine.")
    featured[:orange] = toy.call(box: mixed_box, category: cat.call("Puzzle"), operator: camille, status: "review", price: 8, complete: false,
                                 photo: "mosaique", created_at: days_ago.call(3))
    check.call(featured[:orange], 1, "refused", days_ago.call(2), causes: %w[completude abime],
                                                                  comment: "Il manque des pions rouges et un coin de la boîte est déchiré.", note: "Boîte vérifiée.")
    featured[:recent] = toy.call(box: mixed_box, category: cat.call("Véhicules"), operator: camille, status: "review", price: 5,
                                 photo: "camion", created_at: days_ago.call(2))
    check.call(featured[:recent], 1, "refused", days_ago.call(1), causes: %w[photo],
                                                                  comment: "Photo trop sombre : on ne voit pas la benne. À refaire.")

    featured[:second_round] = toy.call(box: mixed_box, category: cat.call("Figurines"), operator: nadia, status: "pending", price: 9,
                                       photo: "figurines", created_at: days_ago.call(5), location: "Rack B, étagère 2",
                                       operator_note: "Figurines nettoyées une par une, lot recompté : 9 pièces.")
    check.call(featured[:second_round], 1, "refused", days_ago.call(4), causes: %w[nettoyage incoherence],
                                                                        comment: "Deux figurines sont sales et une ne fait pas partie de la série.", note: "Lot de 10 figurines.",
                                                                        reworked: days_ago.call(2))
    featured[:first_round] = toy.call(box: mixed_box, category: cat.call("Jouet premier"), operator: karim, status: "pending", price: 10,
                                      photo: "licorne", created_at: days_ago.call(1),
                                      operator_note: "Piles neuves, la musique et les lumières fonctionnent.")
    featured[:arbitrage] = toy.call(box: mixed_box, category: cat.call("Puzzle"), operator: lucas, status: "arbitrage", price: 7,
                                    photo: "puzzle", created_at: days_ago.call(9))
    check.call(featured[:arbitrage], 1, "refused", days_ago.call(8), causes: %w[completude],
                                                                     comment: "Il manque 3 pièces.", note: "Puzzle 54 pièces.", reworked: days_ago.call(6), resolved: days_ago.call(3))
    check.call(featured[:arbitrage], 2, "refused", days_ago.call(3), causes: %w[completude],
                                                                     comment: "Il manque encore 1 pièce au centre de l'image.", note: "2 pièces retrouvées dans le vrac.")
    featured[:draft] =
      toy.call(box: main_box, category: cat.call("Peluches"), operator: camille, status: "draft", created_at: now - 20.minutes)

    # quelques autres jouets visibles : en attente, prêts, vrac, don, refusés chez les collègues
    { "pompier" => [nadia, "Véhicules", "pending", 6], "briques" => [karim, "Jeux de construction", "pending", 12],
      "poupon" => [camille, "Poupons", "market", 8], "coffret-lecture" => [nadia, "Livres 0", "market", 5],
      "premieres-phrases" => [karim, "Jeux de société 0", "market", 7], "construction" => [lucas, "Jeux de construction", "vrac", nil] }
      .each do |photo, (operator, category, status, price)|
      record = toy.call(box: [main_box, mixed_box].sample(random: rng), category: cat.call(category), operator: operator,
                        status: status, price: price, photo: photo, created_at: days_ago.call(rng.rand(1..4)),
                        location: status == "market" ? "Rack A, étagère #{rng.rand(1..4)}" : Toy::WAITING_LOCATION)
      check.call(record, 1, "accepted", record.created_at + 5.hours) if status == "market"
      check.call(record, 1, "vrac", record.created_at + 5.hours, comment: "Lot incomplet : servira de pièces.") if status == "vrac"
    end
    { nadia => [[2, %w[abime]], [1, %w[prix]]], karim => [[5, %w[panne]], [3, %w[completude]]],
      lucas => [[4, %w[nettoyage securite]], [2, %w[categorie]], [1, %w[completude]]] }.each do |operator, refusals|
      refusals.each do |age, causes|
        record = toy.call(box: mixed_box, category: Category.for_toys.sample(random: rng), operator: operator, status: "review",
                          price: rng.rand(4..15), created_at: days_ago.call(age + 1))
        check.call(record, 1, "refused", days_ago.call(age), causes: causes,
                                                             comment: "À reprendre : #{QualityCause.cq_labels(causes).join(', ').downcase}.")
      end
    end

    # ── Historique de 8 semaines pour le tableau de bord ───────────────────
    cause_weights = { "completude" => 34, "abime" => 19, "nettoyage" => 17, "panne" => 8, "incoherence" => 7, "photo" => 6,
                      "prix" => 4, "securite" => 3, "categorie" => 1, "ce" => 1 }
    pick_cause = lambda do
      target = rng.rand(cause_weights.values.sum)
      cause_weights.find { |_, weight| (target -= weight).negative? }.first
    end
    quality = { camille => 0.90, nadia => 0.86, karim => 0.80, lucas => 0.73 }
    discard_tri = %w[sans_ce trop_abime dangereux electronique puzzle hors_perimetre publicitaire]
    discard_valo = %w[incomplet sale en_panne pas_francais]
    categories = Category.for_toys.to_a

    (1..40).each do |age| # jours ouvrés
      day = days_ago.call(age)
      day_box = box.call(categories.sample(random: rng), sorters[(age % 3).zero? ? 1 : 0], day - 2.hours)
      tri_quality = day_box.actions.first.user == sorters[0] ? 0.96 : 0.90
      operators.each do |operator|
        rng.rand(2..4).times do |i|
          at = day + (i * 40).minutes
          if rng.rand > tri_quality - 0.04 # écarté à l'entrée de la VALO
            tri_fault = rng.rand < 0.6
            causes = [(tri_fault ? discard_tri : discard_valo).sample(random: rng)]
            toy.call(box: day_box, category: day_box.category, operator: operator, discard_causes: causes, created_at: at,
                     status: %w[suppr suppr don vrac].sample(random: rng))
            next
          end
          progress = (40 - age) / 40.0 * 0.06 # la qualité s'améliore au fil des semaines
          if rng.rand < quality[operator] + progress
            record = toy.call(box: day_box, category: day_box.category, operator: operator, status: "market", price: rng.rand(3..20),
                              created_at: at, location: "Rack #{%w[A B C].sample(random: rng)}")
            check.call(record, 1, "accepted", at + 3.hours)
          else
            causes = [pick_cause.call, (pick_cause.call if rng.rand < 0.35)].compact.uniq
            delay = rng.rand(1..4)
            second_at = [days_ago.call([age - delay - 1, 0].max), now - 1.hour].min
            failed_again = rng.rand < 0.15
            record = toy.call(box: day_box, category: day_box.category, operator: operator, price: rng.rand(3..20), created_at: at,
                              status: failed_again ? "vrac" : "market", location: "Rack #{%w[A B C].sample(random: rng)}")
            check.call(record, 1, "refused", at + 3.hours, causes: causes, comment: "À reprendre : #{QualityCause.cq_labels(causes).join(', ').downcase}.",
                                                           reworked: [days_ago.call([age - delay, 0].max), now - 2.hours].min, resolved: second_at)
            if failed_again
              check.call(record, 2, "refused", second_at, causes: causes.first(1), comment: "Toujours pas conforme.",
                                                          resolved: second_at + 1.hour)
              check.call(record, 3, "vrac", second_at + 1.hour, comment: "Servira de pièces.")
            else
              check.call(record, 2, "accepted", second_at, comment: "Revalorisation réussie.")
            end
          end
        end
      end
    end

    # Nombre de jouets annoncé cohérent avec ce qui est déjà sorti. Les trois caisses les plus
    # récentes (en tête de liste) montrent les trois états de la jauge : en cours, complète, dépassée.
    recent = Box.where.not(id: [main_box.id, draft_box.id]).order(created_at: :desc).to_a
    recent.each_with_index do |record, index|
      extra = [6, 0, -1][index] || [0, 0, 2, 5].sample(random: rng)
      record.update_columns(nb_toys: record.toys.not_draft.count + extra)
    end

    QualitySetting.current
    manifest = featured.transform_values(&:id).merge(main_box: main_box.id, mixed_box: mixed_box.id, draft_box: draft_box.id,
                                                     password: password)
    File.write(Rails.root.join("tmp/procedures_demo.json"), JSON.pretty_generate(manifest))
    puts "Démo prête : #{Toy.count} jouets, #{Box.count} caisses, #{QualityCheck.count} contrôles. Mot de passe : #{password}"
  end
end
# rubocop:enable Layout/LineLength
