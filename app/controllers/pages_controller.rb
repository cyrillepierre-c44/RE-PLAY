class PagesController < ApplicationController
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

  def dashboard
    authorize :page, :dashboard?
    @period      = params[:period].presence || "month"
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
    return parse_custom_range if @period == "custom"
    return last_week_range    if @period == "last_week"

    Date.yesterday.beginning_of_day..Date.yesterday.end_of_day
  end

  def last_week_range
    last_monday = Date.current.beginning_of_week(:monday) - 7.days
    last_monday.beginning_of_day..last_monday.next_day(6).end_of_day
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
    build_type_stats
  end

  def build_count_stats
    @total_actions     = @actions.count
    @actions_by_admin  = @actions.joins(:user).where(users: { admin: true }).count
    @actions_by_user   = @actions.joins(:user).where(users: { admin: false }).count
    @toy_actions_count = @actions.where(actionable_type: "Toy").count
    @box_actions_count = @actions.where(actionable_type: "Box").count
  end

  def build_rework_stats
    rework_scope     = @actions.where("content LIKE ?", "%updaté%")
    @rework_total    = rework_scope.count
    @rework_by_admin = rework_scope.joins(:user).where(users: { admin: true }).count
    @rework_by_user  = rework_scope.joins(:user).where(users: { admin: false }).count
  end

  def build_type_stats
    @create_total = @actions.where("content LIKE ?", "%créé%").count
    @verify_total = @actions.where("content LIKE ?", "%passé%").count
    @delete_total = @actions.where("content LIKE ?", "%supprimé%").count
  end
end
