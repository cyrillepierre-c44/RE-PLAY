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

  test "un jouet créé depuis une caisse classique hérite de sa catégorie" do
    sign_in @user
    box = create_box
    get new_box_toy_path(box)
    assert_equal box.category, Toy.last.category
  end

  test "un jouet créé depuis une caisse Grosses pièces n'hérite d'aucune catégorie" do
    sign_in @user
    box = create_box(category: mixed_category)
    assert_difference("Toy.count", 1) { get new_box_toy_path(box) }
    toy = Toy.last
    assert_nil toy.category
    follow_redirect!
    assert_response :success
    # rien de présélectionné, et « Grosses pièces » n'est pas proposée pour un jouet
    assert_select "select#toy_category_id option[selected]", count: 0
    assert_select "select#toy_category_id option", text: "Grosses pièces", count: 0
  end

  test "jouet Grosses pièces : l'enregistrement exige de choisir une catégorie" do
    sign_in @user
    box = create_box(category: mixed_category)
    get new_box_toy_path(box)
    toy = Toy.last

    patch toy_path(toy), params: { from_new: "1", toy: { category_id: "", clean: "1" } }
    assert_response :unprocessable_entity
    assert_nil toy.reload.category
    # le formulaire réaffiché reste celui de la création, avec l'erreur visible
    assert_select "h1", text: /Nouveau jouet/
    assert_select "input[name=from_new]"
    assert_select ".invalid-feedback", text: "La catégorie doit être choisie"

    patch toy_path(toy), params: { toy: { category_id: mixed_category.id } }
    assert_response :unprocessable_entity

    patch toy_path(toy), params: { toy: { category_id: default_category.id } }
    assert_response :redirect
    assert_equal default_category, toy.reload.category
  end

  test "jouet sans catégorie : listes, fiche et vérification s'affichent" do
    box = create_box(category: mixed_category)
    toy = Toy.new(box: box)
    toy.save(validate: false)
    sign_in create_user(admin: true)
    get toys_path
    assert_response :success
    get toy_path(toy)
    assert_response :success
    get verify_toy_path(toy)
    assert_response :success
  end

  test "jeter directement un jouet d'une caisse Grosses pièces" do
    sign_in @user
    box = create_box(category: mixed_category)
    assert_difference("Toy.count", 1) do
      post quick_discard_box_toys_path(box), params: { toy: { clean: "1" } }
    end
    assert_nil Toy.last.category
    assert Toy.last.suppr?
  end

  test "un employé ne peut pas forcer le statut market via le formulaire" do
    sign_in @user
    patch toy_path(@toy), params: { toy: { status: "market", location: "Rayon A" } }
    assert_not_equal "market", @toy.reload.status
  end
end
