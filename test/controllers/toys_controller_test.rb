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

  # ── Brouillons ──────────────────────────────────────────────────────────

  test "nouveau jouet : le numéro est réservé en brouillon, invisible ailleurs que dans « à terminer »" do
    sign_in @user
    box = create_box
    get new_box_toy_path(box)
    draft = Toy.last
    assert draft.draft?
    assert_redirected_to edit_toy_path(draft, new: true)
    assert_not_includes Toy.waiting, draft

    get box_path(box)
    assert_select ".toy-card", count: 0
    assert_select ".draft-chip-id", text: "J#{draft.id}"
    get toys_path
    assert_select ".draft-chip-id", text: "J#{draft.id}"
    assert_select "a.toy-card[href*='/toys/#{draft.id}']", count: 0

    # la fiche d'un brouillon renvoie vers la suite de sa création
    get toy_path(draft)
    assert_redirected_to edit_toy_path(draft, new: true)
  end

  test "un brouillon n'est visible que par son créateur et l'admin" do
    sign_in @user
    box = create_box
    get new_box_toy_path(box)
    sign_out @user

    sign_in create_user
    get box_path(box)
    assert_select ".draft-chip", count: 0
    get toys_path
    assert_select ".draft-chip", count: 0
    sign_out :user

    sign_in create_user(admin: true)
    get box_path(box)
    assert_select ".draft-chip", count: 1
  end

  test "le premier enregistrement transforme le brouillon en jouet en attente" do
    sign_in @user
    get new_box_toy_path(create_box)
    draft = Toy.last
    patch toy_path(draft), params: { from_new: "1", toy: { clean: "1" } }
    assert_redirected_to toy_path(draft, back_box: draft.box_id)
    assert draft.reload.pending?
  end

  test "un enregistrement refusé laisse le jouet en brouillon, flèche retour comprise" do
    sign_in @user
    get new_box_toy_path(create_box(category: mixed_category))
    draft = Toy.last
    patch toy_path(draft), params: { from_new: "1", toy: { category_id: "" } }
    assert_response :unprocessable_entity
    assert draft.reload.draft?
    assert_select "form[action='#{toy_path(draft)}'] input[name=_method][value=delete]"
  end

  test "la flèche retour du formulaire supprime le brouillon et son historique" do
    sign_in @user
    box = create_box
    get new_box_toy_path(box)
    draft = Toy.last
    follow_redirect!
    assert_select "form[action='#{toy_path(draft)}'] input[name=_method][value=delete]"

    assert_difference(["Toy.count", "Action.count"], -1) { delete toy_path(draft) }
    assert_redirected_to box_path(box)
  end

  test "supprimer un vrai jouet passe toujours par la corbeille" do
    sign_in @user
    assert_no_difference("Toy.count") { delete toy_path(@toy) }
    assert @toy.reload.suppr?
  end

  test "un brouillon ne peut pas être supprimé par un autre employé" do
    sign_in @user
    get new_box_toy_path(create_box)
    draft = Toy.last
    sign_out @user
    sign_in create_user
    assert_no_difference("Toy.count") { delete toy_path(draft) }
  end

  test "un employé ne peut pas forcer le statut market via le formulaire" do
    sign_in @user
    patch toy_path(@toy), params: { toy: { status: "market", location: "Rayon A" } }
    assert_not_equal "market", @toy.reload.status
  end
end
