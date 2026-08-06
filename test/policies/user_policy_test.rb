require "test_helper"

class UserPolicyTest < ActiveSupport::TestCase
  setup do
    @admin       = create_user(admin: true)
    @other_admin = create_user(admin: true)
    @employee    = create_user
  end

  test "toggle_admin/disable/enable : admin uniquement, jamais sur soi-même" do
    assert UserPolicy.new(@admin, @employee).toggle_admin?
    assert UserPolicy.new(@admin, @other_admin).disable?
    assert UserPolicy.new(@admin, @employee).enable?

    assert_not UserPolicy.new(@admin, @admin).toggle_admin?, "un admin ne peut pas s'auto-rétrograder"
    assert_not UserPolicy.new(@admin, @admin).disable?, "un admin ne peut pas s'auto-désactiver"
    assert_not UserPolicy.new(@employee, @admin).toggle_admin?
    assert_not UserPolicy.new(@employee, @employee).disable?
  end

  test "scope : lève NotAuthorizedError pour un non-admin" do
    assert_raises(Pundit::NotAuthorizedError) do
      UserPolicy::Scope.new(@employee, User.all).resolve
    end
    assert_includes UserPolicy::Scope.new(@admin, User.all).resolve, @employee
  end
end
