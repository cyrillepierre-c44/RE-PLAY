require "test_helper"

class QualityDashboardTest < ActiveSupport::TestCase
  setup do
    @admin = create_user(admin: true)
    @alice = create_user(email: "alice@example.com")
    @bob = create_user(email: "bob@example.com")
    @range = 1.day.ago..1.day.from_now
  end

  def check(operator, decision, causes: [], comment: nil)
    toy = create_toy(operator: operator, location: "Rack A")
    control = QualityControl.new(toy, checker: @admin)
    assert control.decide(outcome: decision, causes: causes, comment: comment), toy.errors.full_messages.to_sentence
    toy
  end

  test "bon du 1er coup VALO, causes et lignes par opérateur" do
    3.times { check(@alice, "market") }
    check(@alice, "review", causes: %w[nettoyage completude], comment: "Sale et incomplet")
    check(@bob, "review", causes: %w[completude], comment: "Incomplet")
    check(@bob, "don", comment: "Trop usé") # ni bon ni non conforme

    q = QualityDashboard.new(@range)
    assert_equal [5, 3, 60, 40], [q.valo_total, q.valo_ok, q.fpy_valo, q.nc_rate]
    assert_equal 3, q.problems_count
    assert_equal %w[completude nettoyage], q.cause_rows.map { |row| row[:cause].key }
    assert_equal [2, 1], q.cause_rows.map { |row| row[:count] }
    assert_equal [67, 100], q.cause_rows.map { |row| row[:cumulative] }

    alice, bob = q.operator_rows
    assert_equal [@alice, 4, 75, 2, 1], [alice[:user], alice[:total], alice[:fpy], alice[:problems], alice[:open]]
    assert_equal [@bob, 1, 0, 1], [bob[:user], bob[:total], bob[:fpy], bob[:problems]]
    assert_equal 2, q.open_checks.size

    title, rows = q.detail(cause: "completude", operator_id: @bob.id)
    assert_match(/Complétude · bob/, title)
    assert_equal ["Incomplet"], rows.map(&:cq_comment)
  end

  test "non-conformités ouvertes et en retard, délai de retraitement" do
    toy = check(@alice, "review", causes: %w[photo], comment: "Floue")
    monday = Time.find_zone("Europe/Paris").parse("2026-11-09 10:00")
    refusal = toy.quality_checks.sole
    refusal.update_columns(created_at: monday)

    travel_to monday + 8.days do
      q = QualityDashboard.new(monday - 1.day..monday + 9.days)
      assert_equal [1, 1, 6], [q.open_checks.size, q.late_checks.size, q.oldest_open_days]
      refusal.update!(reworked_at: monday + 2.days)
      toy.update_columns(status: "pending")
      q = QualityDashboard.new(monday - 1.day..monday + 9.days)
      assert_equal [0, 2.0], [q.open_checks.size, q.rework_delay]
    end
  end

  test "bon du 1er coup TRI : seules les causes du TRI comptent, par créateur de caisse" do
    box = create_box
    touch(box, @alice) # alice a créé (trié) la caisse
    3.times { create_toy(box: box, operator: @bob) }
    create_toy(box: box, operator: @bob, status: "suppr", discard_causes: %w[sans_ce])
    create_toy(box: box, operator: @bob, status: "suppr", discard_causes: %w[incomplet]) # pas la faute du TRI
    create_toy(box: box, status: "draft") # brouillon : ignoré

    q = QualityDashboard.new(@range)
    assert_equal [5, 1, 1, 80], [q.toys_out.size, q.tri_rejects.size, q.valo_rejects.size, q.fpy_tri]
    row = q.sorter_rows.sole
    assert_equal [@alice, 5, 1, 80], [row[:user], row[:total], row[:rejected], row[:fpy]]
    _title, toys = q.detail(scope: "tri", sorter_id: @alice.id)
    assert_equal [%w[sans_ce]], toys.map(&:discard_causes)
  end

  test "un refus sans cause (historique) compte comme un problème non renseigné" do
    toy = create_toy(operator: @alice)
    QualityCheck.new(toy: toy, round: 1, decision: "refused", causes: [], operator: @alice, checker: @admin).save!(validate: false)

    q = QualityDashboard.new(@range)
    assert_equal 1, q.problems_count
    assert_equal ["inconnue"], q.cause_rows.map { |row| row[:cause].key }
    row = q.operator_rows.sole
    assert_equal [1, 1, { "inconnue" => 1 }], [row[:refused], row[:problems], row[:causes]]
    title, rows = q.detail(cause: "inconnue")
    assert_match(/non renseignée/, title)
    assert_equal [toy.id], rows.map(&:toy_id)
  end

  test "seuil de fiabilité : pas de pourcentage sous min_sample, vue du jour sur une journée" do
    3.times { check(@alice, "market") }
    refused = check(@alice, "review", causes: %w[photo], comment: "Floue")
    refused.quality_checks.sole.update!(reworked_at: Time.current)

    q = QualityDashboard.new(@range)
    row = q.operator_rows.sole
    assert_not q.reliable?(q.valo_total)
    assert_equal [false, 3, 4, 1], [row[:reliable], row[:ok], row[:total], row[:reworked]]
    assert q.weekly.all? { |week| week[:fpy].nil? }, "pas de point sur la courbe sous le seuil"
    assert_not q.daily?
    assert QualityDashboard.new(Time.current.beginning_of_day..Time.current.end_of_day).daily?

    QualitySetting.current.update!(min_sample: 4)
    q = QualityDashboard.new(@range)
    assert q.reliable?(q.valo_total)
    assert q.operator_rows.sole[:reliable]
    assert q.weekly.all? { |week| week[:fpy].nil? }, "la semaine en cours n'est pas sur la courbe"
  end

  test "la courbe s'arrête à la dernière semaine complète" do
    QualitySetting.current.update!(min_sample: 1)
    monday = Time.find_zone("Europe/Paris").parse("2026-11-16 09:00")
    toy = check(@alice, "market")
    toy.quality_checks.sole.update_columns(created_at: monday - 3.days) # vendredi de la semaine 46

    travel_to monday + 1.day do # mardi de la semaine 47
      weeks = QualityDashboard.new(monday - 30.days..monday + 2.days).weekly
      assert_equal "S46", weeks.last[:label]
      assert_equal 100, weeks.last[:fpy]
    end
  end

  test "tableau opérateurs × causes : en taux pour 100 jouets, pas en nombre brut" do
    QualitySetting.current.update!(min_sample: 5)
    18.times { check(@alice, "market") }
    2.times { check(@alice, "review", causes: %w[completude], comment: "Incomplet") } # 2 problèmes sur 20 = 10 %
    3.times { check(@bob, "market") }
    2.times { check(@bob, "review", causes: %w[completude], comment: "Incomplet") }   # 2 problèmes sur 5 = 40 %
    carl = create_user(email: "carl@example.com")
    check(carl, "review", causes: %w[completude], comment: "Incomplet")               # 1 jouet : sous le seuil

    rows = QualityDashboard.new(@range).matrix_rows
    assert_equal %w[bob alice carl], rows.map { |row| row[:user].email.split("@").first }, "le plus fort taux d'abord, pas le plus gros volume"
    assert_equal [40.0, 10.0, nil], rows.map { |row| row[:rates]["completude"] }
    assert_equal [40.0, 10.0, nil], rows.map { |row| row[:problem_rate] }
    assert_equal 40.0, QualityDashboard.new(@range).matrix_max_rate
  end

  test "sans données, rien ne casse" do
    q = QualityDashboard.new(@range)
    assert_nil q.fpy_valo
    assert_nil q.fpy_tri
    assert_empty q.cause_rows
    assert_empty q.operator_rows
    assert_equal QualityDashboard::WEEKS, q.weekly.size
  end
end
