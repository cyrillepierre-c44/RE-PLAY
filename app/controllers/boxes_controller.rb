class BoxesController < ApplicationController
  before_action :set_box, only: %i[show edit update destroy toggle_empty restore]

  def index
    base_scope = policy_scope(Box)
    base_scope = base_scope.where(category_id: params[:category_id]) if params[:category_id].present?
    if params[:q].present?
      num = params[:q].to_s.gsub(/\D/, '')
      @boxes = num.present? ? base_scope.where(id: num) : base_scope.none
      if @boxes.one?
        b = @boxes.first
        @active_filter = if b.suppr? then "suppr"
                         elsif b.empty? then "empty"
                         end
      end
    elsif params[:filter] == "suppr"
      @boxes = base_scope.suppr.order(created_at: :desc)
    elsif params[:filter] == "empty"
      @boxes = base_scope.empty.order(created_at: :desc)
    else
      @boxes = base_scope.active.order(created_at: :desc)
    end
    own = current_user.admin? ? Box : Box.where(id: Action.where(actionable_type: "Box", user: current_user).select(:actionable_id))
    @count_scope = params[:category_id].present? ? own.where(category_id: params[:category_id]) : own
    @categories = Category.all.order(:name)
  end

  def show
    authorize @box
    toys = @box.toys
    @timeline = Action.where(actionable: @box)
                      .or(Action.where(actionable: toys))
                      .includes(:user)
                      .order(created_at: :desc)
  end

  def new
    @box = Box.new
    authorize @box
  end

  def create
    @box = Box.new(box_params)
    authorize @box
    if @box.save
      Action.create!(user: current_user, actionable: @box, content: "#{current_user.email} a créé la caisse C#{@box.id}")
      if params[:new_flow]
        redirect_to edit_box_path(@box, new: true), status: :see_other
      else
        redirect_to box_path(@box)
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @box
  end

  def update
    authorize @box
    @box.update(box_params)
    Action.create!(user: current_user, actionable: @box, content: "#{current_user.email} a modifié la caisse C#{@box.id}")
    redirect_to box_path(@box), status: :see_other
  end

  def destroy
    authorize @box
    if @box.toys.where.not(status: :suppr).any?
      redirect_to box_path(@box), alert: "Impossible de supprimer une caisse qui contient encore des jouets."
      return
    end
    if @box.update(status: :suppr)
      Action.create!(
        user: current_user,
        actionable: @box,
        content: "#{current_user.email} a supprimé la caisse C#{@box.id}"
      )
      redirect_to boxes_path, notice: "Caisse supprimée."
    else
      redirect_to box_path(@box), alert: @box.errors.full_messages.to_sentence
    end
  end

  def restore
    authorize @box
    if @box.update(status: :pending)
      Action.create!(user: current_user, actionable: @box, content: "#{current_user.email} a remis la caisse C#{@box.id} en cours")
      redirect_to box_path(@box), notice: "Caisse C#{@box.id} remise en cours."
    else
      redirect_to box_path(@box), alert: @box.errors.full_messages.to_sentence
    end
  end

  def toggle_empty
    authorize @box
    new_status = @box.empty? ? :pending : :empty
    @box.update(status: new_status)
    label = new_status == :empty ? "marqué la caisse C#{@box.id} comme vide" : "marqué la caisse C#{@box.id} comme non vide"
    Action.create!(user: current_user, actionable: @box, content: "#{current_user.email} a #{label}")
    redirect_to box_path(@box), notice: new_status == :empty ? "✅ La caisse C#{@box.id} est bien vidée !" : nil
  end

  private

  def set_box
    @box = Box.find(params[:id])
  end

  def box_params
    params.require(:box).permit(:category_id, :electronic, :status, :nb_toys)
  end
end
