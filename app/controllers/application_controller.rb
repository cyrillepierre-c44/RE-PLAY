class ApplicationController < ActionController::Base
  # Les listes n'affichent que PER_PAGE cartes à la fois : avec ~1 900 jouets en
  # attente (nov. 2026), tout afficher d'un coup demandait 5 s et 3,8 Mo.
  PER_PAGE = 48

  before_action :authenticate_user!
  include Pundit::Authorization

  # Pas de only:/except: ici : lister une action absente d'un controller
  # (ex. index sur PagesController) déclenche raise_on_missing_callback_actions
  # en test — le dispatch se fait donc dans la méthode.
  after_action :verify_pundit_authorization, unless: :skip_pundit?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  protected

  # Un opérateur qui prend son poste traite d'abord ses revalorisations : s'il a
  # des jouets « CQ refusé » à sa charge, il arrive directement dessus.
  def after_sign_in_path_for(resource)
    if resource.is_a?(User) && !resource.admin? && Toy.review.held_by(resource).exists?
      toys_path(filter: "review")
    else
      super
    end
  end

  private

  def paginate(records)
    @total = records.is_a?(Array) ? records.size : records.count
    @pages = [(@total / PER_PAGE.to_f).ceil, 1].max
    @page = params[:page].to_i.clamp(1, @pages)
    offset = (@page - 1) * PER_PAGE
    records.is_a?(Array) ? records.slice(offset, PER_PAGE) || [] : records.offset(offset).limit(PER_PAGE).load
  end

  def user_not_authorized
    flash[:alert] = "Vous n'êtes pas autorisé à effectuer cette action."
    redirect_to(request.referer || root_path)
  end

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
