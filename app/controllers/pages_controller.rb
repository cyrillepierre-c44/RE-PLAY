require "csv"

class PagesController < ApplicationController
  include DashboardPareto

  skip_before_action :authenticate_user!, only: [:home]

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

  def cyrille_pierre
  end

  def marc_thomas
  end

  def loic_laplagne
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
        type  = action.actionable_type == "Toy" ? "Jouet" : "Boîte"
        role  = action.user&.admin ? "Admin" : "Utilisateur"
        objet = "#{type} \##{action.actionable_id}"
        csv << [
          action.created_at.strftime("%d/%m/%Y %H:%M"),
          action.user&.email&.split("@")&.first,
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
  end

  def dashboard
    authorize :page, :dashboard?
    @period      = params[:period].presence || "prev_day"
    @type_filter = params[:type].presence
    @category_id = params[:category_id].presence
    @user_id     = params[:user_id].presence
    @actions     = filtered_actions
    build_dashboard_stats
    @recent_actions = @actions.order(created_at: :desc).limit(100)
    @categories     = Category.all
    @users          = User.order(:email)
  end

  private

  def filtered_actions
    scope = Action.where(created_at: period_range).includes(:user).preload(:actionable)
    scope = filter_by_type(scope)
    scope = filter_by_category(scope)
    scope = scope.where(user_id: @user_id) if @user_id.present?
    scope
  end

  def period_range
    return parse_custom_range               if @period == "custom"
    return last_week_range                  if @period == "last_week"
    return Time.current.beginning_of_day..Time.current.end_of_day if @period == "today"

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

  def build_dashboard_stats
    build_count_stats
    build_rework_stats
    build_nc_stats
    build_type_stats
    build_pareto_stats
  end

  def build_count_stats
    @total_actions     = @actions.count
    @actions_by_admin  = @actions.joins(:user).where(users: { admin: true }).count
    @actions_by_user   = @actions.joins(:user).where(users: { admin: false }).count
    @toy_actions_count = @actions.where(actionable_type: "Toy").count
    @box_actions_count = @actions.where(actionable_type: "Box").count
    @box_ids           = @actions.where(actionable_type: "Box").pluck(:actionable_id).uniq
    @toy_ids           = @actions.where(actionable_type: "Toy").pluck(:actionable_id).uniq
    @boxes_toys_count          = Toy.where(box_id: @box_ids).count
    @boxes_toys_electronic     = Toy.joins(:box).where(boxes: { id: @box_ids, electronic: true }).count
    @boxes_toys_non_electronic = Toy.joins(:box).where(boxes: { id: @box_ids, electronic: false }).count
    elec_base     = Toy.joins(:box).where(boxes: { id: @box_ids, electronic: true })
    non_elec_base = Toy.joins(:box).where(boxes: { id: @box_ids, electronic: false })
    @elec_waiting      = elec_base.waiting.count
    @non_elec_waiting  = non_elec_base.waiting.count
    @elec_validated    = elec_base.validated.count
    @non_elec_validated = non_elec_base.validated.count
    @elec_deleted      = elec_base.deleted.count
    @non_elec_deleted  = non_elec_base.deleted.count
    @toys_price_total   = Toy.validated.where(id: @toy_ids).sum(:price)
    @toys_price_pending = Toy.waiting.where(id: @toy_ids).sum(:price)
  end

  def build_rework_stats
    # Retouches = jouets renvoyés via "Revaloriser" (statut review), par les admins uniquement
    review_scope     = @actions.where("content LIKE ?", "%en statut: review%")
    @review_total    = review_scope.count
    @review_by_admin = review_scope.joins(:user).where(users: { admin: true }).count
    @review_by_user  = review_scope.joins(:user).where(users: { admin: false }).count
  end

  def build_nc_stats
    nc_scope = @actions.where("content LIKE ?", "%[NC:%]%")
    @nc_total = nc_scope.count

    @nc_by_type = [
      { key: "NC:propre",    label: "Propre",    icon: "fa-soap",       count: nc_scope.where("content LIKE ?", "%[NC:propre]%").count },
      { key: "NC:complet",   label: "Complet",   icon: "fa-list-check", count: nc_scope.where("content LIKE ?", "%[NC:complet]%").count },
      { key: "NC:jouable",   label: "Jouable",   icon: "fa-gamepad",    count: nc_scope.where("content LIKE ?", "%[NC:jouable]%").count },
      { key: "NC:catégorie", label: "Catégorie", icon: "fa-tag",        count: nc_scope.where("content LIKE ?", "%[NC:catégorie]%").count }
    ]

    nc_toy_ids = nc_scope.where(actionable_type: "Toy").pluck(:actionable_id).uniq
    return @nc_by_creator = [] if nc_toy_ids.empty?

    creator_map = Action
      .select("DISTINCT ON (actionable_id) actionable_id, user_id")
      .where(actionable_type: "Toy", actionable_id: nc_toy_ids)
      .where("content LIKE ?", "%créé%")
      .order("actionable_id, created_at ASC")
      .each_with_object({}) { |a, h| h[a.actionable_id] = a.user_id }

    nc_counts_by_toy = nc_scope
      .where(actionable_type: "Toy", actionable_id: nc_toy_ids)
      .group(:actionable_id)
      .count

    creator_counts = Hash.new(0)
    nc_counts_by_toy.each do |toy_id, count|
      creator_id = creator_map[toy_id]
      creator_counts[creator_id] += count if creator_id
    end

    users = User.where(id: creator_counts.keys).index_by(&:id)

    @nc_by_creator = creator_counts
      .map { |user_id, count| { user: users[user_id], count: count } }
      .sort_by { |item| -item[:count] }
      .first(10)
  end

  def build_type_stats
    @create_total = @actions.where("content LIKE ?", "%créé%").count
    @verify_total = @actions.where("content LIKE ?", "%passé%").count
    @delete_total = @actions.where("content LIKE ?", "%supprimé%").count
  end
end
