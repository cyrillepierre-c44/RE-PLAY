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
