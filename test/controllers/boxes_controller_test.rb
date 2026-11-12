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

  test "création d'une caisse Grosses pièces" do
    sign_in @user
    assert_difference("Box.count", 1) do
      post boxes_path, params: { box: { category_id: mixed_category.id } }
    end
    assert_equal mixed_category, Box.last.category
  end

  test "show d'une caisse Grosses pièces avec un jouet sans catégorie" do
    box = create_box(category: mixed_category)
    toy = Toy.new(box: box)
    toy.save(validate: false)
    sign_in create_user(admin: true)
    get box_path(box)
    assert_response :success
    assert_includes response.body, "À choisir"
  end
end
