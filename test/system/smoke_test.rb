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
    # Attendre la fin de la redirection post-connexion avant de naviguer,
    # sinon le visit suivant part en course avec elle.
    assert_current_path root_path

    visit boxes_path
    assert_current_path boxes_path
    assert_selector "h1"
  end
end
