module Users
  class RegistrationsController < Devise::RegistrationsController
    skip_before_action :require_no_authentication, only: %i[new create]
    before_action :require_admin!, only: %i[new create destroy]

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

    def after_update_path_for(_resource)
      root_path
    end

    protected

    # L'adresse e-mail est attribuée par Enjoué et sert d'identifiant dans tout
    # l'historique des actions : elle n'est pas modifiable depuis « Mon profil »
    # (un changement se fait en base, par Cyrille). Le 05/11/2026, une collègue
    # sur un appareil partagé avait remplacé l'e-mail d'un autre compte par le
    # sien, faisant « disparaître » ce compte.
    def update_resource(resource, params)
      params.delete(:email)
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
      return if current_user&.admin?

      redirect_to root_path, alert: "Accès réservé aux administrateurs."
    end
  end
end
