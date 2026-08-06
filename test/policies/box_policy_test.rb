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
end
