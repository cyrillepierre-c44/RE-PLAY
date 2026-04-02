class WelcomeMailer < ApplicationMailer
  default from: "centaurbike.gestion@gmail.com"

  def welcome_email(user, reset_token)
    @user = user
    @reset_url = edit_user_password_url(reset_password_token: reset_token)
    mail(to: @user.email, subject: "Bienvenue sur RE-PLAY !")
  end
end
