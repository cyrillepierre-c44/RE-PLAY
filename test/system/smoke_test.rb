require "application_system_test_case"

class SmokeTest < ApplicationSystemTestCase
  test "la page d'accueil publique s'affiche" do
    visit root_path
    assert_selector "body"
    assert_no_text "Exception"
  end

  test "un utilisateur peut se connecter et voir les caisses" do
    create_user(email: "operateur@example.com")

    visit new_user_session_path
    fill_in "Adresse e-mail", with: "operateur@example.com"
    fill_in "Mot de passe", with: "motdepasse"
    click_button "Se connecter"

    visit boxes_path
    assert_current_path boxes_path
  end
end
