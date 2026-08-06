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

  test "show refusé à un utilisateur étranger au jouet (redirection, pas de 500)" do
    sign_in create_user
    get toy_path(@toy)
    assert_redirected_to root_path
    assert_equal "Vous n'êtes pas autorisé à effectuer cette action.", flash[:alert]
  end

  test "verify réservé à l'admin" do
    sign_in create_user(admin: true)
    get verify_toy_path(@toy)
    assert_response :success
  end

  test "verify refusé à un employé (redirection, pas de 500)" do
    sign_in @user
    get verify_toy_path(@toy)
    assert_redirected_to root_path
    assert flash[:alert].present?
  end

  test "un employé ne peut pas forcer le statut market via le formulaire" do
    sign_in @user
    patch toy_path(@toy), params: { toy: { status: "market", location: "Rayon A" } }
    assert_not_equal "market", @toy.reload.status
  end
end
