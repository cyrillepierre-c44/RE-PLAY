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
