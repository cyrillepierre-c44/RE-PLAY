require "test_helper"

# L'adresse e-mail est attribuée par Enjoué et n'est pas modifiable depuis
# « Mon profil ». Incident du 05/11/2026 : sur un appareil partagé encore
# connecté, une collègue avait remplacé l'e-mail du compte de Laurence par le
# sien, faisant « disparaître » ce compte de la liste.
module Users
  class RegistrationsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = create_user
      sign_in @user
    end

    test "le formulaire du profil affiche l'e-mail sans champ pour le modifier" do
      get edit_user_registration_path
      assert_response :success
      assert_select ".form-card-subtitle", text: @user.email
      assert_select "input[name='user[email]']", count: 0
    end

    test "un paramètre email envoyé est ignoré, même avec le mot de passe actuel" do
      put user_registration_path, params: { user: { email: "autre@enjoue.org", current_password: "motdepasse" } }
      assert_redirected_to root_path
      assert_equal @user.email, @user.reload.email
    end

    test "un paramètre email envoyé avec un nouveau mot de passe est ignoré" do
      put user_registration_path, params: {
        user: { email: "autre@enjoue.org", password: "nouveau-mdp", password_confirmation: "nouveau-mdp", current_password: "motdepasse" }
      }
      assert_redirected_to root_path
      original_email = @user.email
      @user.reload
      assert_equal original_email, @user.email
      assert @user.valid_password?("nouveau-mdp")
    end

    test "changer le mot de passe sans le mot de passe actuel est refusé" do
      put user_registration_path, params: { user: { password: "nouveau-mdp", password_confirmation: "nouveau-mdp" } }
      assert_response :unprocessable_entity
      assert @user.reload.valid_password?("motdepasse")
    end
  end
end
