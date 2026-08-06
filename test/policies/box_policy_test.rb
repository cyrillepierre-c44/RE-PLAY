require "test_helper"

class BoxPolicyTest < ActiveSupport::TestCase
  setup do
    @admin    = create_user(admin: true)
    @toucher  = create_user
    @stranger = create_user
    @box      = create_box
    touch(@box, @toucher)
  end

  test "scope : tout le monde voit toutes les caisses (choix métier)" do
    resolved = BoxPolicy::Scope.new(@stranger, Box.all).resolve
    assert_includes resolved, @box
  end

  test "show : ouvert à tout utilisateur authentifié (choix métier)" do
    assert BoxPolicy.new(@stranger, @box).show?
  end

  test "update/destroy : admin ou utilisateur ayant touché la caisse" do
    assert BoxPolicy.new(@admin, @box).update?
    assert BoxPolicy.new(@toucher, @box).update?
    assert_not BoxPolicy.new(@stranger, @box).update?

    assert BoxPolicy.new(@admin, @box).destroy?
    assert BoxPolicy.new(@toucher, @box).destroy?
    assert_not BoxPolicy.new(@stranger, @box).destroy?
  end

  test "restore : admin ou utilisateur ayant touché la caisse" do
    assert BoxPolicy.new(@admin, @box).restore?
    assert BoxPolicy.new(@toucher, @box).restore?
    assert_not BoxPolicy.new(@stranger, @box).restore?
  end

  test "toggle_empty : admin, ou dernier utilisateur à avoir créé un jouet de la caisse" do
    first_creator = create_user
    last_creator  = create_user

    first_toy = create_toy(box: @box)
    touch(first_toy, first_creator)
    last_toy = create_toy(box: @box)
    touch(last_toy, last_creator)

    assert BoxPolicy.new(@admin, @box).toggle_empty?
    assert BoxPolicy.new(last_creator, @box).toggle_empty?, "le dernier créateur peut corriger une fausse manip"
    assert_not BoxPolicy.new(first_creator, @box).toggle_empty?, "un créateur antérieur ne peut plus"
    assert_not BoxPolicy.new(@stranger, @box).toggle_empty?
  end

  test "toggle_empty : refusé à un non-admin sur une caisse sans jouet" do
    assert_not BoxPolicy.new(@stranger, @box).toggle_empty?
    assert BoxPolicy.new(@admin, @box).toggle_empty?
  end
end
