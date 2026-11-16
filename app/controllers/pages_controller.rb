require "csv"

class PagesController < ApplicationController
  skip_before_action :authenticate_user!,
                     only: %i[home mentions_legales confidentialite cgu aide]

  def home
  end

  def about_us
    authorize :page, :about_us?
  end

  def onboarding
    authorize :page, :onboarding?
  end

  def enjoue
  end

  # Procédures consultables dans l'appli et imprimables en PDF. `admin: true` =
  # réservée aux administrateurs (contrôle qualité, tableau de bord).
  PROCEDURES = {
    "operateur" => { title: "Opérateur", icon: "fa-hands-holding-child", admin: false, template: "operateur",
                     summary: "Reprendre un jouet refusé, écarter un jouet, jouets à terminer." },
    "controle-qualite" => { title: "Contrôle qualité", icon: "fa-magnifying-glass", admin: true, template: "controle_qualite",
                            summary: "Causes, commentaires, 2e tour, arbitrage, réattribution." },
    "tableau-de-bord" => { title: "Tableau de bord", icon: "fa-chart-bar", admin: true, template: "tableau_de_bord",
                           summary: "Lire les indicateurs, aller au détail, régler les objectifs." }
  }.freeze

  def procedures
    authorize :page, :onboarding?
    @procedures = PROCEDURES.reject { |_, procedure| procedure[:admin] && !current_user.admin? }
  end

  def procedure
    procedure = PROCEDURES[params[:slug]] or raise ActiveRecord::RecordNotFound
    authorize :page, procedure[:admin] ? :dashboard? : :onboarding?
    render "pages/procedures/#{procedure[:template]}"
  end

  def cyrille_pierre
  end

  def marc_thomas
  end

  def loic_laplagne
  end

  def mentions_legales
  end

  def confidentialite
  end

  def cgu
  end

  def aide
  end

  def export_csv
    authorize :page, :export_csv?
    @period      = params[:period].presence || "prev_day"
    @type_filter = params[:type].presence
    @category_id = params[:category_id].presence
    @user_id     = params[:user_id].presence
    @start_date  = params[:start_date].presence
    @end_date    = params[:end_date].presence
    actions = filtered_actions.order(created_at: :desc).includes(:user).preload(:actionable)

    csv_data = CSV.generate(headers: true, col_sep: ";") do |csv|
      csv << ["Date", "Utilisateur", "Rôle", "Type", "Action", "Objet"]
      actions.each do |action|
        action_label = if action.content&.include?("créé") then "Création"
                       elsif action.content&.include?("modifié") || action.content&.include?("updaté") then "Mise à jour"
                       elsif action.content&.include?("passé") then "Validation"
                       elsif action.content&.include?("supprimé") then "Suppression"
                       else "Autre"
                       end
        type  = action.actionable_type == "Toy" ? "Jouet" : "Caisse"
        role  = action.user&.admin ? "Admin" : "Utilisateur"
        prefix = action.actionable_type == "Toy" ? "J" : "C"
        objet = "#{prefix}#{action.actionable_id}"
        csv << [
          action.created_at.strftime("%d/%m/%Y %H:%M"),
          action.user&.email.to_s.split("@").first,
          role,
          type,
          action_label,
          objet
        ]
      end
    end

    filename = "journal_actions_#{Date.current.strftime('%Y%m%d')}.csv"
    send_data "\xEF\xBB\xBF#{csv_data}",
              filename: filename,
              type: "text/csv; charset=utf-8",
              disposition: "attachment"
  end

  def projet
    authorize :page, :projet?
    @leviers = ProjetLevier.all.index_by { |l| [l.module_code, l.numero] }
    { "A" => 1..5, "B" => 1..5, "C" => 1..5, "D" => 1..2 }.each do |mod, nums|
      nums.each do |num|
        unless @leviers[[mod, num]]
          lev = ProjetLevier.create!(module_code: mod, numero: num)
          @leviers[[mod, num]] = lev
        end
      end
    end
  end

  def dashboard
    authorize :page, :dashboard?
    @period      = params[:period].presence || "prev_day"
    @type_filter = params[:type].presence
    @category_id = params[:category_id].presence
    @user_id     = params[:user_id].presence
    @actions     = filtered_actions
    @quality = QualityDashboard.new(period_range)
    @recent_actions = @actions.order(created_at: :desc).limit(100)
    @categories     = Category.all
    @users          = User.order(:email)
  end

  # Détail d'un chiffre du volet qualité (clic sur une barre, un point, une case) :
  # liste des jouets avec les commentaires du CQ et de l'opérateur, dans un turbo-frame.
  def quality_detail
    authorize :page, :dashboard?
    @period = params[:period].presence || "prev_day"
    @quality = QualityDashboard.new(period_range)
    @title, @rows = @quality.detail(params.permit(:scope, :cause, :operator_id, :sorter_id, :week))
    render layout: false
  end

  PERIOD_NAMES = { "today" => "Aujourd'hui", "prev_day" => "Dernier jour ouvré", "last_week" => "Semaine dernière",
                   "four_weeks" => "4 dernières semaines", "month" => "Mois en cours", "custom" => "Dates libres" }.freeze

  # Période en clair, pour l'en-tête des documents imprimés.
  def period_label
    range = period_range
    first, last = [range.begin, range.end].map { |time| time.strftime("%d/%m/%Y") }
    dates = first == last ? "le #{first}" : "du #{first} au #{last}"
    "#{PERIOD_NAMES.fetch(@period, 'Période')} · #{dates}"
  end
  helper_method :period_label

  private

  def filtered_actions
    scope = Action.where(created_at: period_range)
    scope = filter_by_type(scope)
    scope = filter_by_category(scope)
    scope = scope.where(user_id: @user_id) if @user_id.present?
    scope
  end

  def period_range
    return parse_custom_range               if @period == "custom"
    return last_week_range                  if @period == "last_week"
    return Time.current.beginning_of_day..Time.current.end_of_day if @period == "today"
    return 27.days.ago.beginning_of_day..Time.current.end_of_day if @period == "four_weeks"
    return Time.current.beginning_of_month..Time.current.end_of_day if @period == "month"

    prev = previous_working_day
    prev.beginning_of_day..prev.end_of_day
  end

  def last_week_range
    last_monday = Date.current.beginning_of_week(:monday) - 7.days
    last_monday.beginning_of_day..last_monday.next_day(6).end_of_day
  end

  def previous_working_day
    day = Date.current - 1.day
    day -= 1.day while day.saturday? || day.sunday?
    day
  end

  def parse_custom_range
    @start_date = params[:start_date].presence
    @end_date   = params[:end_date].presence
    start_dt = @start_date ? Date.parse(@start_date).beginning_of_day : 1.month.ago.beginning_of_day
    end_dt   = @end_date   ? Date.parse(@end_date).end_of_day         : Time.current.end_of_day
    start_dt..end_dt
  end

  def filter_by_type(scope)
    return scope.where(actionable_type: "Toy") if @type_filter == "toys"
    return scope.where(actionable_type: "Box") if @type_filter == "boxes"

    scope
  end

  def filter_by_category(scope)
    return scope unless @category_id.present?

    toy_ids = Toy.where(category_id: @category_id).pluck(:id).presence || [0]
    box_ids = Box.where(category_id: @category_id).pluck(:id).presence || [0]
    scope.where(
      "(actionable_type = 'Toy' AND actionable_id IN (:toy_ids)) OR " \
      "(actionable_type = 'Box' AND actionable_id IN (:box_ids))",
      toy_ids: toy_ids, box_ids: box_ids
    )
  end
end
