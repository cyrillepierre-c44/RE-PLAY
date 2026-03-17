class Users::RegistrationsController < Devise::RegistrationsController
  skip_before_action :require_no_authentication, only: [:new, :create]
  before_action :require_admin!, only: [:new, :create]

  def create
    build_resource(sign_up_params)
    resource.save
    if resource.persisted?
      redirect_to users_path, notice: "Compte créé pour #{resource.email}."
    else
      clean_up_passwords resource
      render :new, status: :unprocessable_entity
    end
  end

  private

  def require_admin!
    unless current_user&.admin?
      redirect_to root_path, alert: "Accès réservé aux administrateurs."
    end
  end
end
