class Users::RegistrationsController < Devise::RegistrationsController
  skip_before_action :require_no_authentication, only: [:new, :create]
  before_action :require_admin!, only: [:new, :create, :destroy]

  def create
    build_resource(sign_up_params.merge(password: generated_password, password_confirmation: generated_password))
    resource.save
    if resource.persisted?
      raw_token, hashed_token = Devise.token_generator.generate(User, :reset_password_token)
      resource.update_columns(reset_password_token: hashed_token, reset_password_sent_at: Time.now.utc)
      WelcomeMailer.welcome_email(resource, raw_token).deliver_now
      redirect_to users_path, notice: "Compte créé pour #{resource.email}."
    else
      clean_up_passwords resource
      render :new, status: :unprocessable_entity
    end
  end

  def after_update_path_for(resource)
    root_path
  end

  protected

  def update_resource(resource, params)
    if params[:password].blank?
      params.delete(:current_password)
      params.delete(:password)
      params.delete(:password_confirmation)
      resource.update_without_password(params)
    else
      resource.update_with_password(params)
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
