require "test_helper"
require "rake"

class QualityBackfillTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("quality:backfill")
    Rake::Task["quality:backfill"].reenable
    @admin = create_user(admin: true)
    @operator = create_user
  end

  def log(toy, user, content, at)
    Action.create!(user: user, actionable: toy, content: content, created_at: at)
  end

  test "reconstruit les tours et fusionne les refus répétés sans retouche" do
    toy = create_toy(operator: @operator, status: "review")
    t = 10.days.ago
    log(toy, @operator, "#{@operator.email} a créé le jouet J#{toy.id}", t)
    # bouton « Revaloriser » cliqué trois fois de suite
    3.times { |i| log(toy, @admin, "#{@admin.email} a passé le jouet J#{toy.id} en statut: review", t + 1.hour + i.minutes) }
    log(toy, @admin, "[NC:propreté] #{@admin.email} a renvoyé propreté du jouet J#{toy.id}", t + 1.hour + 2.minutes)
    log(toy, @operator, "#{@operator.email} a modifié le jouet J#{toy.id}", t + 1.day)
    log(toy, @admin, "#{@admin.email} a passé le jouet J#{toy.id} en statut: review", t + 2.days)

    accepted = create_toy(operator: @operator, status: "market")
    log(accepted, @admin, "#{@admin.email} a passé le jouet J#{accepted.id} en statut: market", t)

    assert_output(/1 validés, 2 refusés/) { Rake::Task["quality:backfill"].invoke }

    checks = toy.quality_checks.order(:created_at)
    assert_equal [[1, "refused"], [2, "refused"]], checks.map { |c| [c.round, c.decision] }
    assert_equal %w[nettoyage], checks.first.causes
    assert_not_nil checks.first.resolved_at
    assert_equal [[1, "accepted"]], accepted.quality_checks.map { |c| [c.round, c.decision] }

    Rake::Task["quality:backfill"].reenable
    assert_output(/0 validés, 0 refusés/) { Rake::Task["quality:backfill"].invoke }
  end
end
