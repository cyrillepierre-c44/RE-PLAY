require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "home accessible sans authentification" do
    get root_path
    assert_response :success
  end

  test "healthcheck /up répond 200 sans authentification" do
    get rails_health_check_path
    assert_response :success
  end

  test "les pages légales et l'aide sont publiques" do
    [ mentions_legales_path, confidentialite_path, cgu_path, aide_path ].each do |path|
      get path
      assert_response :success, "#{path} devrait répondre 200 sans authentification"
    end
  end

  test "le footer expose les liens légaux" do
    get root_path
    assert_select "footer nav a", minimum: 5
  end

  test "dashboard réservé à l'admin" do
    sign_in create_user(admin: true)
    get dashboard_path
    assert_response :success
  end

  test "dashboard : volet qualité avec des données, détail au clic et réglage des objectifs" do
    admin = create_user(admin: true)
    operator = create_user(email: "zoe@example.com")
    box = create_box
    touch(box, operator)
    2.times do |i|
      toy = create_toy(box: box, operator: operator, location: "Rack A")
      QualityControl.new(toy, checker: admin).decide(outcome: i.zero? ? "market" : "review",
                                                     causes: %w[nettoyage], comment: "Encore sale")
    end
    create_toy(box: box, operator: operator, status: "suppr", discard_causes: %w[dangereux])

    sign_in admin
    %w[today four_weeks month last_week prev_day].each do |period|
      get dashboard_path(period: period)
      assert_response :success, "période #{period}"
    end
    # 2 jouets contrôlés : sous le seuil, pas de pourcentage ; sur une journée, vue « suivi du jour »
    get dashboard_path(period: "today")
    assert_select ".quality-hero", count: 0
    assert_select ".quality-small-sample", text: /Moins de 20 jouets/
    assert_select "h3", text: /suivi du jour/
    assert_select ".quality-table th", text: "Retraités"
    assert_select ".quality-stock-bar .quality-stock-ontime", text: "1" # le refus du jour, dans les délais
    get dashboard_path(period: "four_weeks")
    assert_select ".quality-small-sample", text: "1 sur 2"

    QualitySetting.current.update!(min_sample: 1)
    get dashboard_path(period: "today")
    assert_select ".quality-hero", text: "50 %"
    assert_select ".quality-bar-row", text: /Nettoyage/
    assert_select ".quality-table th a", text: "zoe"
    assert_select ".quality-now-tile .quality-now-value", text: "1"

    get dashboard_quality_detail_path(period: "today", cause: "nettoyage")
    assert_response :success
    assert_select "turbo-frame#quality-detail td", text: "Encore sale"
    get dashboard_quality_detail_path(period: "today", scope: "tri", cause: "dangereux")
    assert_select "turbo-frame#quality-detail td", text: "Dangereux"
    get dashboard_quality_detail_path(period: "today", scope: "open")
    assert_select "turbo-frame#quality-detail td", text: /Ouverte/
    get dashboard_quality_detail_path(period: "today", week: Date.current.beginning_of_week(:monday).iso8601)
    assert_response :success

    patch quality_setting_path, params: { quality_setting: { target_valo: 85, target_tri: 97, red_after_days: 2, min_sample: 15 } }
    assert_equal [85, 97, 2, 15], QualitySetting.current.then { |s| [s.target_valo, s.target_tri, s.red_after_days, s.min_sample] }
    patch quality_setting_path, params: { quality_setting: { target_valo: 150 } }
    assert_equal 85, QualitySetting.current.target_valo
  end

  test "volet qualité refusé à un employé" do
    sign_in create_user
    get dashboard_quality_detail_path
    assert_redirected_to root_path
    patch quality_setting_path, params: { quality_setting: { target_valo: 10 } }
    assert_equal 90, QualitySetting.current.target_valo
  end

  test "procédures : l'opérateur ne voit que la sienne, l'admin les trois" do
    get procedures_path
    assert_redirected_to new_user_session_path

    sign_in create_user
    get procedures_path
    assert_select "a.procedure-card", count: 1
    get procedure_path("operateur")
    assert_response :success
    assert_select ".procedure-causes li", count: QualityCause::DISCARD.size
    %w[controle-qualite tableau-de-bord].each do |slug|
      get procedure_path(slug)
      assert_redirected_to root_path
    end
    sign_out :user

    sign_in create_user(admin: true)
    get procedures_path
    assert_select "a.procedure-card", count: 3
    %w[operateur controle-qualite tableau-de-bord].each do |slug|
      get procedure_path(slug)
      assert_response :success, slug
      assert_select "button", text: "Imprimer en PDF"
    end
    assert_select ".procedure-table td", text: "#{QualitySetting.current.target_valo} %"
    get procedure_path("inconnue")
    assert_response :not_found
  end

  test "dashboard refusé à un employé (redirection, pas de 500)" do
    sign_in create_user
    get dashboard_path
    assert_redirected_to root_path
    assert flash[:alert].present?
  end

  test "projet réservé à l'admin (et crée les leviers A-D à la volée)" do
    sign_in create_user(admin: true)
    get projet_path
    assert_response :success
    assert_equal 17, ProjetLevier.count
    assert_equal 2, ProjetLevier.where(module_code: "D").count
  end

  test "projet refusé à un employé (redirection, pas de 500)" do
    sign_in create_user
    get projet_path
    assert_redirected_to root_path
    assert flash[:alert].present?
  end
end
