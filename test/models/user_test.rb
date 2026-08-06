require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "non admin et non désactivé par défaut" do
    user = create_user
    assert_not user.admin?
    assert_not user.disabled?
  end

  test "un compte désactivé ne peut plus s'authentifier" do
    user = create_user(disabled: true)
    assert_not user.active_for_authentication?
    assert_equal :disabled, user.inactive_message
  end

  test "un compte actif peut s'authentifier" do
    user = create_user
    assert user.active_for_authentication?
  end

  test "exige un email valide et unique" do
    create_user(email: "unique@example.com")
    doublon = User.new(email: "unique@example.com", password: "motdepasse")
    assert_not doublon.valid?

    invalide = User.new(email: "pas-un-email", password: "motdepasse")
    assert_not invalide.valid?
  end
end
