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

  test "dashboard réservé à l'admin" do
    sign_in create_user(admin: true)
    get dashboard_path
    assert_response :success
  end

  test "dashboard refusé à un employé" do
    sign_in create_user
    assert_raises(Pundit::NotAuthorizedError) { get dashboard_path }
  end

  test "projet réservé à l'admin (et crée les leviers A-D à la volée)" do
    sign_in create_user(admin: true)
    get projet_path
    assert_response :success
    assert_equal 17, ProjetLevier.count
    assert_equal 2, ProjetLevier.where(module_code: "D").count
  end

  test "projet refusé à un employé" do
    sign_in create_user
    assert_raises(Pundit::NotAuthorizedError) { get projet_path }
  end
end
