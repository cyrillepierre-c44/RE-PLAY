require "test_helper"

class BoxTest < ActiveSupport::TestCase
  test "prend le statut pending par défaut" do
    assert_equal "pending", Box.new.status
    assert_equal "pending", create_box.status
  end

  test "refuse un statut hors enum" do
    assert_raises(ArgumentError) { create_box(status: "cassé") }
  end

  test "exige une catégorie" do
    box = Box.new
    assert_not box.valid?
    assert_includes box.errors.attribute_names, :category
  end

  test "scope active couvre pending, deleted couvre suppr" do
    active_box = create_box
    empty_box  = create_box(status: "empty")
    suppr_box  = create_box(status: "suppr")

    assert_equal [ active_box.id ], Box.active.ids
    assert_equal [ suppr_box.id ], Box.deleted.ids
    assert_not_includes Box.active.ids, empty_box.id
  end

  test "détruire une caisse détruit ses jouets" do
    box = create_box
    create_toy(box: box)
    assert_difference("Toy.count", -1) { box.destroy }
  end
end
