require "test_helper"

# Incident du 05/11/2026 : sur un appareil partagé encore connecté, une
# collègue a remplacé l'e-mail du compte de Laurence par le sien depuis
# « Mon profil », sans qu'aucun mot de passe ne soit demandé.
module Users
  class RegistrationsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = create_user
      sign_in @user
    end

    test "changer l'e-mail sans mot de passe actuel est refusé" do
      put user_registration_path, params: { user: { email: "autre@enjoue.org" } }
      assert_response :unprocessable_entity
      assert_equal @user.email, @user.reload.email
    end

    test "changer l'e-mail avec un mauvais mot de passe actuel est refusé" do
      put user_registration_path, params: { user: { email: "autre@enjoue.org", current_password: "faux" } }
      assert_response :unprocessable_entity
      assert_equal @user.email, @user.reload.email
    end

    test "changer l'e-mail avec le mot de passe actuel fonctionne" do
      put user_registration_path, params: { user: { email: "autre@enjoue.org", current_password: "motdepasse" } }
      assert_redirected_to root_path
      assert_equal "autre@enjoue.org", @user.reload.email
    end

    test "le formulaire du profil surveille le champ e-mail pour afficher le mot de passe actuel" do
      get edit_user_registration_path
      assert_response :success
      assert_select "form[data-controller~=current-password][data-current-password-original-email-value=?]", @user.email
      assert_select "input[name='user[email]'][data-current-password-target=email]"
      assert_select "#current-password-field"
    end

    test "renvoyer le même e-mail (casse ou espaces différents) ne demande pas de mot de passe" do
      put user_registration_path, params: { user: { email: " #{@user.email.upcase} " } }
      assert_redirected_to root_path
      assert_equal @user.email, @user.reload.email
    end
  end
end
