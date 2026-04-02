class Users::PasswordsController < Devise::PasswordsController
  def edit
    super
    token = params[:reset_password_token]
    if token.present?
      hashed = Devise.token_generator.digest(User, :reset_password_token, token)
      @user_email = User.find_by(reset_password_token: hashed)&.email
    end
  end
end
