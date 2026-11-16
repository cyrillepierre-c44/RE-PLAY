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

  test "sans données, rien ne casse" do
    q = QualityDashboard.new(@range)
    assert_nil q.fpy_valo
    assert_nil q.fpy_tri
    assert_empty q.cause_rows
    assert_empty q.operator_rows
    assert_equal QualityDashboard::WEEKS, q.weekly.size
  end
end
