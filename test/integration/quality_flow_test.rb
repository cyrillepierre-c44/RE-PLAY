require "test_helper"

# Parcours qualité : CQ refusé → retraitement → 2e tour → arbitrage.
class QualityFlowTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create_user(admin: true)
    @operator = create_user
    @toy = create_toy(operator: @operator, operator_note: "Nettoyé au chiffon")
    touch(@toy, @operator)
  end

  def decide(toy, status, causes: [], comment: nil, location: "Rack A")
    patch confirm_verify_toy_path(toy),
          params: { status: status, quality: { causes: causes, comment: comment }, toy: { location: location } }
  end

  test "1er tour : mise en vente sans commentaire = bon du 1er coup" do
    sign_in @admin
    decide(@toy, "market")
    assert_redirected_to toys_path
    assert @toy.reload.market?
    check = @toy.quality_checks.sole
    assert_equal [1, "accepted", "Nettoyé au chiffon"], [check.round, check.decision, check.operator_comment]
    assert_equal @operator, check.operator
    assert_equal @admin, check.checker
  end

  test "mise en vente refusée sans emplacement" do
    sign_in @admin
    decide(@toy, "market", location: "")
    assert_response :unprocessable_entity
    assert @toy.reload.pending?
    assert_empty @toy.quality_checks
  end

  test "un refus exige au moins une cause et un commentaire" do
    sign_in @admin
    decide(@toy, "review", causes: [], comment: "sale")
    assert_response :unprocessable_entity
    decide(@toy, "review", causes: %w[nettoyage], comment: " ")
    assert_response :unprocessable_entity
    assert_select "#cq_cause_nettoyage[checked]" # la saisie est conservée
    decide(@toy, "review", causes: %w[inconnue], comment: "sale")
    assert_response :unprocessable_entity
    assert @toy.reload.pending?
    assert_equal "Nettoyé au chiffon", @toy.operator_note
    assert_empty @toy.quality_checks
  end

  test "parcours complet : refus, retraitement, 2e refus, arbitrage vers le vrac" do
    sign_in @admin
    decide(@toy, "review", causes: %w[nettoyage completude], comment: "Encore sale, il manque un dé")
    assert @toy.reload.review?
    assert_nil @toy.operator_note, "la note du 2e tour doit être libre"
    first = @toy.quality_checks.sole
    assert_equal %w[nettoyage completude], first.causes
    assert_equal 1, QualityCheck.awaiting_rework.count
    sign_out @admin

    # l'opérateur arrive sur ses CQ refusés dès la connexion
    post user_session_path, params: { user: { email: @operator.email, password: "motdepasse" } }
    assert_redirected_to toys_path(filter: "review")
    follow_redirect!
    assert_select ".toy-card-review-badge", text: /CQ refusé/
    get edit_toy_path(@toy)
    assert_select ".quality-round--past", text: /Encore sale, il manque un dé/
    assert_select ".quality-round--past", text: /Nettoyé au chiffon/
    assert_select "textarea[name='toy[operator_note]']", text: ""

    patch toy_path(@toy), params: { toy: { operator_note: "Nettoyé à nouveau, dé ajouté", clean: "1" } }
    assert_redirected_to toys_path(filter: "review")
    assert @toy.reload.pending?
    assert_not_nil first.reload.reworked_at
    assert_equal 0, QualityCheck.awaiting_rework.count
    sign_out @operator

    sign_in @admin
    get verify_toy_path(@toy)
    assert_select ".quality-round-title", text: /2e tour/
    # 2e tour : commentaire obligatoire même pour valider
    decide(@toy, "market")
    assert_response :unprocessable_entity
    decide(@toy, "review", causes: %w[completude], comment: "Il manque toujours le dé")
    assert @toy.reload.arbitrage?
    assert_equal [1, 2], @toy.quality_checks.order(:id).pluck(:round)

    # à arbitrer : plus de renvoi possible, l'admin choisit la destination
    get toys_path(filter: "arbitrage")
    assert_select ".toy-card-review-badge", text: /À arbitrer/
    get verify_toy_path(@toy)
    assert_select "button[name=status][value=review]", count: 0
    decide(@toy, "review", causes: %w[completude], comment: "encore")
    assert_response :unprocessable_entity
    decide(@toy, "vrac")
    assert_response :unprocessable_entity
    decide(@toy, "vrac", comment: "Servira de pièces")
    assert_redirected_to toys_path(filter: "arbitrage")
    assert @toy.reload.vrac?
    assert_equal [1, 2, 3], @toy.quality_checks.order(:id).pluck(:round)
    assert_empty @toy.quality_checks.unresolved
    get toys_path(filter: "vrac")
    assert_select "a.toy-card[href*='/toys/#{@toy.id}']"
  end

  test "une cause liée à un critère le décoche, même si le contrôle l'avait laissé coché" do
    @toy.update_columns(clean: true, complete: true, playable: true)
    sign_in @admin
    patch confirm_verify_toy_path(@toy),
          params: { status: "review", quality: { causes: %w[nettoyage photo], comment: "Sale, photo floue" },
                    toy: { clean: "1", complete: "1", playable: "1" } }
    @toy.reload
    assert @toy.review?
    assert_not @toy.clean?, "refusé pour Nettoyage : le jouet ne doit plus être affiché Propre"
    assert @toy.complete?
    assert @toy.playable?
    get verify_toy_path(@toy)
    assert_select "input[name='quality[causes][]'][value=nettoyage][data-criterion=clean]"
    assert_select "input[name='quality[causes][]'][value=photo][data-criterion]", count: 0
  end

  test "2e tour validé avec commentaire" do
    sign_in @admin
    decide(@toy, "review", causes: %w[photo], comment: "Photo floue")
    sign_out @admin
    sign_in @operator
    patch toy_path(@toy), params: { toy: { clean: "1" } }
    sign_out @operator
    sign_in @admin
    decide(@toy, "market", comment: "Revalorisation réussie")
    assert @toy.reload.market?
    assert_equal %w[refused accepted], @toy.quality_checks.order(:id).pluck(:decision)
    assert_empty @toy.quality_checks.unresolved
  end

  test "don ou rebut dès le 1er tour : commentaire obligatoire" do
    sign_in @admin
    decide(@toy, "don")
    assert_response :unprocessable_entity
    decide(@toy, "don", comment: "Trop usé pour la vente")
    assert @toy.reload.don?
    other = create_toy(operator: @operator)
    decide(other, "suppr", comment: "Dangereux")
    assert other.reload.suppr?
    assert_equal "discarded", other.quality_checks.sole.decision
  end

  test "corriger un jouet déjà en vente ne crée pas de nouveau contrôle" do
    sign_in @admin
    decide(@toy, "market")
    decide(@toy, "market", location: "Rack B")
    assert_equal "Rack B", @toy.reload.location
    assert_equal 1, @toy.quality_checks.count
  end

  test "bandeau orange puis rouge selon les jours ouvrés" do
    sign_in @admin
    decide(@toy, "review", causes: %w[nettoyage], comment: "Sale")
    check = @toy.quality_checks.sole
    monday = Time.find_zone("Europe/Paris").parse("2026-11-16 10:00")
    check.update_columns(created_at: monday)

    travel_to monday + 3.days do # jeudi : 3 jours ouvrés, encore orange
      assert_not check.late?
      reset! # la session Devise expire quand on voyage dans le temps
      sign_in @admin
      get toys_path(filter: "review")
      assert_select ".toy-card-review-badge--late", count: 0
      assert_select ".toy-card-review-badge", text: /3 j/
    end
    travel_to monday + 4.days do # vendredi : 4e jour, rouge
      assert check.late?
      reset!
      sign_in @admin
      get toys_path(filter: "review")
      assert_select ".toy-card-review-badge--late", text: /en retard/
      assert_select ".filter-tab-rework--late"
    end
    QualitySetting.current.update!(red_after_days: 5)
    travel_to(monday + 4.days) { assert_not check.reload.late? }
  end

  test "réattribution : l'admin confie un CQ refusé à un autre opérateur" do
    other = create_user
    sign_in @admin
    decide(@toy, "review", causes: %w[nettoyage], comment: "Sale")
    patch reassign_toy_path(@toy), params: { user_id: other.id }
    assert_equal other, @toy.reload.assignee
    assert_equal @operator, @toy.operator, "la non-conformité reste au valorisateur d'origine"
    sign_out @admin

    post user_session_path, params: { user: { email: other.email, password: "motdepasse" } }
    assert_redirected_to toys_path(filter: "review")
    follow_redirect!
    assert_select "a.toy-card[href*='/toys/#{@toy.id}']"
    get edit_toy_path(@toy)
    assert_response :success
    patch toy_path(@toy), params: { toy: { clean: "1" } }
    assert @toy.reload.pending?
    sign_out other

    # le valorisateur d'origine ne l'a plus dans sa liste « à reprendre »
    post user_session_path, params: { user: { email: @operator.email, password: "motdepasse" } }
    assert_redirected_to root_path
  end

  test "le bloc Confier n'apparaît pas pendant qu'un admin crée son propre jouet" do
    sign_in @admin
    get new_box_toy_path(create_box)
    follow_redirect!
    assert_select ".reassign-box", count: 0

    # mais il apparaît sur le brouillon laissé par un opérateur absent, et sur un jouet enregistré
    draft = create_toy(operator: @operator, status: "draft")
    get edit_toy_path(draft, new: true)
    assert_select ".reassign-box button", text: /Confier/
    get toy_path(@toy)
    assert_select ".reassign-box button", text: /Confier/
  end

  test "réattribution refusée à un opérateur" do
    sign_in @operator
    patch reassign_toy_path(@toy), params: { user_id: create_user.id }
    assert_nil @toy.reload.assignee
  end

  test "jet à l'entrée : au moins une cause, enregistrée sur le jouet" do
    sign_in @operator
    box = create_box
    assert_no_difference("Toy.count") { post quick_discard_box_toys_path(box), params: { toy: { operator_note: "x" } } }
    assert_redirected_to box_path(box)
    assert_difference("Toy.count", 1) do
      post quick_discard_box_toys_path(box), params: { toy: { discard_causes: %w[sans_ce incomplet pirate] } }
    end
    toy = Toy.last
    assert_equal %w[sans_ce incomplet], toy.discard_causes
    assert_equal @operator, toy.operator
    assert toy.suppr?, "sans destination choisie : rebut"

    # l'opérateur peut aussi choisir le don ou le vrac
    post quick_discard_box_toys_path(box), params: { toy: { discard_causes: %w[hors_perimetre], destination: "don" } }
    assert Toy.last.don?
    post quick_discard_box_toys_path(box), params: { toy: { discard_causes: %w[incomplet], destination: "vrac" } }
    assert Toy.last.vrac?
    post quick_discard_box_toys_path(box), params: { toy: { discard_causes: %w[incomplet], destination: "market" } }
    assert Toy.last.suppr?, "destination inconnue : rebut"

    get box_path(box)
    assert_select "#quickDiscardModal input[name='toy[destination]']", count: 3
    assert_select "#quickDiscardModal .cause-chips:not(.discard-destinations) .cause-chip", count: QualityCause::DISCARD.size
    assert_select "#quickDiscardModal .cause-legend li", count: QualityCause::DISCARD.size
  end

  test "un nouveau jouet est rattaché à son valorisateur" do
    sign_in @operator
    get new_box_toy_path(create_box)
    assert_equal @operator, Toy.last.operator
  end
end
