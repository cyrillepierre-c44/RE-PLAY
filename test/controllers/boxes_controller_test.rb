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

  test "jauge de progression : jouets sortis sur jouets annoncés, tous opérateurs confondus" do
    box = Box.create!(category: default_category, status: "pending", nb_toys: 4)
    create_toy(box: box)                       # celui d'un collègue : invisible en liste, compté dans la jauge
    create_toy(box: box, status: "suppr")      # écarté : sorti quand même
    mine = create_toy(box: box)
    touch(mine, @user)
    Toy.new(box: box, status: "draft").save(validate: false) # brouillon : pas compté
    sign_in @user
    get box_path(box)
    assert_select ".box-progress-head strong", text: "3"
    assert_select ".box-progress-head", text: %r{3\s*/ 4 jouets}
    assert_select "h2", text: /Mes jouets · 1/
    assert_select ".box-progress-fill[style*='width: 75%']"
    assert_select "a.toy-card", count: 1

    create_toy(box: box)
    get box_path(box)
    assert_select ".box-progress--done .fa-circle-check"
    assert_select ".box-progress--over", count: 0

    # un jouet de plus qu'annoncé : alerte rouge, plus de coche verte
    create_toy(box: box)
    get box_path(box)
    assert_select ".box-progress--over .fa-triangle-exclamation"
    assert_select ".box-progress .fa-circle-check", count: 0
    assert_select ".box-progress-fill[style*='width: 100%']"
    Toy.where(box: box).last.destroy

    # la jauge figure aussi sur la carte de la caisse, dans la liste
    get boxes_path
    assert_select "a.box-card[href*='/boxes/#{box.id}'] .box-progress--compact .box-progress-head", text: %r{4\s*/ 4 jouets}
  end

  test "création d'une caisse" do
    sign_in @user
    assert_difference("Box.count", 1) do
      post boxes_path, params: { box: { category_id: default_category.id, nb_toys: 5 } }
    end
    assert_response :redirect
    assert Box.last.pending?
  end

  # ── Brouillons ──────────────────────────────────────────────────────────

  test "création en deux étapes : brouillon après l'étape 1, en cours après l'étape 2" do
    sign_in @user
    post boxes_path, params: { new_flow: true, box: { category_id: default_category.id } }
    draft = Box.last
    assert draft.draft?
    assert_redirected_to edit_box_path(draft, new: true)

    get boxes_path
    assert_select ".draft-chip-id", text: "C#{draft.id}"
    assert_select "a.box-card[href*='/boxes/#{draft.id}']", count: 0
    get box_path(draft)
    assert_redirected_to edit_box_path(draft, new: true)

    patch box_path(draft), params: { box: { nb_toys: 3 } }
    assert draft.reload.pending?
  end

  test "une caisse en brouillon n'apparaît pas chez un autre employé" do
    sign_in @user
    post boxes_path, params: { new_flow: true, box: { category_id: default_category.id } }
    sign_out @user
    sign_in create_user
    get boxes_path
    assert_select ".draft-chip", count: 0
    get box_path(Box.last)
    assert_redirected_to boxes_path
  end

  test "la flèche retour de l'étape 2 supprime la caisse en brouillon et son historique" do
    sign_in @user
    post boxes_path, params: { new_flow: true, box: { category_id: default_category.id } }
    draft = Box.last
    follow_redirect!
    assert_select "form[action='#{box_path(draft)}'] input[name=_method][value=delete]"
    assert_difference(["Box.count", "Action.count"], -1) { delete box_path(draft) }
    assert_redirected_to boxes_path
  end

  test "un jouet en brouillon ne bloque pas la suppression de la caisse et disparaît avec elle" do
    sign_in @user
    touch(@box, @user)
    get new_box_toy_path(@box)
    assert_difference("Toy.count", -1) { delete box_path(@box) }
    assert @box.reload.suppr?
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
