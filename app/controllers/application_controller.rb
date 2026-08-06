class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  include Pundit::Authorization

  # Pas de only:/except: ici : lister une action absente d'un controller
  # (ex. index sur PagesController) déclenche raise_on_missing_callback_actions
  # en test — le dispatch se fait donc dans la méthode.
  after_action :verify_pundit_authorization, unless: :skip_pundit?

  private

  def verify_pundit_authorization
    if action_name == "index"
      verify_policy_scoped
    else
      verify_authorized
    end
  end

  def skip_pundit?
    devise_controller? || params[:controller] =~ /(^(rails_)?admin)|(^pages$)/
  end
end
