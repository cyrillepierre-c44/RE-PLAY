require "test_helper"

class ToyPolicyTest < ActiveSupport::TestCase
  setup do
    @admin    = create_user(admin: true)
    @creator  = create_user
    @stranger = create_user
    @toy      = create_toy
    touch(@toy, @creator)
  end

  test "scope : l'admin voit tous les jouets" do
    other_toy = create_toy
    resolved = ToyPolicy::Scope.new(@admin, Toy.all).resolve
    assert_includes resolved, @toy
    assert_includes resolved, other_toy
  end

  test "scope : un employé ne voit que les jouets qu'il a touchés" do
    other_toy = create_toy
    resolved = ToyPolicy::Scope.new(@creator, Toy.all).resolve
    assert_includes resolved, @toy
    assert_not_includes resolved, other_toy
  end

  test "show : admin et créateur oui, étranger non" do
    assert ToyPolicy.new(@admin, @toy).show?
    assert ToyPolicy.new(@creator, @toy).show?
    assert_not ToyPolicy.new(@stranger, @toy).show?
  end

  test "update/destroy : admin et créateur oui, un étranger non" do
    assert ToyPolicy.new(@admin, @toy).update?
    assert ToyPolicy.new(@admin, @toy).destroy?
    assert ToyPolicy.new(@creator, @toy).update?
    assert ToyPolicy.new(@creator, @toy).destroy?
    assert_not ToyPolicy.new(@stranger, @toy).update?
    assert_not ToyPolicy.new(@stranger, @toy).destroy?
  end

  test "verify et confirm_verify : réservés à l'admin" do
    assert ToyPolicy.new(@admin, @toy).verify?
    assert ToyPolicy.new(@admin, @toy).confirm_verify?
    assert_not ToyPolicy.new(@creator, @toy).verify?
    assert_not ToyPolicy.new(@creator, @toy).confirm_verify?
  end

  test "actions de prix IA : réservées à l'admin" do
    assert ToyPolicy.new(@admin, @toy).refresh_price?
    assert ToyPolicy.new(@admin, @toy).purge_deleted?
    assert_not ToyPolicy.new(@creator, @toy).refresh_price?
    assert_not ToyPolicy.new(@creator, @toy).purge_deleted?
  end

  test "quick_discard : réservé aux non-admins" do
    assert ToyPolicy.new(@creator, @toy).quick_discard?
    assert_not ToyPolicy.new(@admin, @toy).quick_discard?
  end
end
