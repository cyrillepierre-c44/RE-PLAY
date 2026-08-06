require "test_helper"

class BoxesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user
    @box  = create_box
  end

  test "redirige vers la connexion sans session" do
    get boxes_path
    assert_redirected_to new_user_session_path
  end

  test "index accessible connecté" do
    sign_in @user
    get boxes_path
    assert_response :success
  end

  test "show accessible à tout utilisateur connecté" do
    sign_in @user
    get box_path(@box)
    assert_response :success
  end

  test "création d'une caisse" do
    sign_in @user
    assert_difference("Box.count", 1) do
      post boxes_path, params: { box: { category_id: default_category.id, nb_toys: 5 } }
    end
    assert_response :redirect
  end
end
