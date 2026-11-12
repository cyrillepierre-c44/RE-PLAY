require "test_helper"

class ToyTest < ActiveSupport::TestCase
  test "prend le statut pending par défaut" do
    assert_equal "pending", Toy.new.status
    assert_equal "pending", create_toy.status
  end

  test "refuse un statut hors enum" do
    assert_raises(ArgumentError) { create_toy(status: "n_importe_quoi") }
  end

  test "exige une caisse et une catégorie" do
    toy = Toy.new
    assert_not toy.valid?
    assert_includes toy.errors.attribute_names, :box
    assert_includes toy.errors.attribute_names, :category
  end

  test "refuse la catégorie Grosses pièces, réservée aux caisses" do
    toy = Toy.new(box: create_box, category: mixed_category)
    assert_not toy.valid?
    assert_includes toy.errors.attribute_names, :category
  end

  test "purge des brouillons : seuls ceux de plus de 7 jours, jouets et caisses" do
    box = create_box
    old_toy    = create_toy(box: box, status: "draft", created_at: 8.days.ago)
    recent_toy = create_toy(box: box, status: "draft", created_at: 6.days.ago)
    old_real   = create_toy(box: box, created_at: 8.days.ago)
    old_box    = Box.create!(category: default_category, status: "draft", created_at: 8.days.ago)
    touch(old_toy, create_user)

    assert_difference("Action.count", -1) { PurgeDraftsJob.perform_now }

    assert_not Toy.exists?(old_toy.id)
    assert_not Box.exists?(old_box.id)
    assert Toy.exists?(recent_toy.id)
    assert Toy.exists?(old_real.id)
  end

  test "discard_draft! refuse un jouet qui n'est pas un brouillon" do
    assert_raises(ArgumentError) { create_toy.discard_draft! }
  end

  test "scope waiting couvre pending et review, validated couvre market, deleted couvre suppr" do
    pending_toy = create_toy
    review_toy  = create_toy(status: "review")
    market_toy  = create_toy(status: "market")
    suppr_toy   = create_toy(status: "suppr")

    assert_equal [ pending_toy.id, review_toy.id ].sort, Toy.waiting.ids.sort
    assert_equal [ market_toy.id ], Toy.validated.ids
    assert_equal [ suppr_toy.id ], Toy.deleted.ids
  end

  test "scopes sold et available se partagent les jouets" do
    sold_toy      = create_toy(sold: true)
    available_toy = create_toy

    assert_equal [ sold_toy.id ], Toy.sold.ids
    assert_includes Toy.available.ids, available_toy.id
    assert_not_includes Toy.available.ids, sold_toy.id
  end
end
