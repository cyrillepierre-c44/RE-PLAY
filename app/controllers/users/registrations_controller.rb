class Users::RegistrationsController < Devise::RegistrationsController
  skip_before_action :require_no_authentication, only: [:new, :create]
  before_action :require_admin!, only: [:new, :create]

  def create
    build_resource(sign_up_params.merge(password: generated_password, password_confirmation: generated_password))
    resource.save
    if resource.persisted?
      token = resource.send_reset_password_instructions
      WelcomeMailer.welcome_email(resource).deliver_later
      redirect_to users_path, notice: "Compte créé pour #{resource.email}."
    else
      clean_up_passwords resource
      render :new, status: :unprocessable_entity
    end
  end

  private

  def generated_password
    @generated_password ||= SecureRandom.hex(16)
  end

  def require_admin!
    unless current_user&.admin?
      redirect_to root_path, alert: "Accès réservé aux administrateurs."
    end
  end
end
