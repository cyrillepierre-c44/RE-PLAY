class WelcomeMailer < ApplicationMailer
  default from: "centaurbike.gestion@gmail.com"

  def welcome_email(user)
    @user = user
    mail(to: @user.email, subject: "Bienvenue sur RE-PLAY !")
  end
end
