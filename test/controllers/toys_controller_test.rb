require "test_helper"

class ToysControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user
    @toy  = create_toy
    touch(@toy, @user)
  end

  test "redirige vers la connexion sans session" do
    get toys_path
    assert_redirected_to new_user_session_path
  end

  test "index accessible connecté" do
    sign_in @user
    get toys_path
    assert_response :success
  end

  test "show accessible au créateur du jouet" do
    sign_in @user
    get toy_path(@toy)
    assert_response :success
  end

  test "show refusé à un utilisateur étranger au jouet" do
    sign_in create_user
    assert_raises(Pundit::NotAuthorizedError) { get toy_path(@toy) }
  end

  test "verify réservé à l'admin" do
    sign_in create_user(admin: true)
    get verify_toy_path(@toy)
    assert_response :success
  end

  test "verify refusé à un employé" do
    sign_in @user
    assert_raises(Pundit::NotAuthorizedError) { get verify_toy_path(@toy) }
  end
end
