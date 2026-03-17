class BoxesController < ApplicationController
  before_action :set_box, only: %i[show edit update destroy toggle_empty]

  def index
    base_scope = policy_scope(Box)
    if params[:filter] == "suppr"
      @boxes = base_scope.suppr
    elsif params[:filter] == "empty"
      @boxes = base_scope.empty
    else
      @boxes = base_scope.active
    end
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
      Action.create!(user: current_user, actionable: @box, content: "#{current_user.email} à créé la boite n#{@box.id}")
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
    Action.create!(user: current_user, actionable: @box, content: "#{current_user.email} à updaté la boite n#{@box.id}")
    redirect_to box_path(@box), status: :see_other
  end

  def destroy
    authorize @box
    if @box.update(status: :suppr)
      Action.create!(
        user: current_user,
        actionable: @box,
        content: "#{current_user.email} a supprimé la boite n°#{@box.id}"
      )
      redirect_to boxes_path, notice: "Boîte supprimée."
    else
      redirect_to box_path(@box), alert: @box.errors.full_messages.to_sentence
    end
  end

  def toggle_empty
    authorize @box
    new_status = @box.empty? ? :pending : :empty
    @box.update(status: new_status)
    label = new_status == :empty ? "marqué la boite n°#{@box.id} comme vide" : "marqué la boite n°#{@box.id} comme non vide"
    Action.create!(user: current_user, actionable: @box, content: "#{current_user.email} a #{label}")
    if new_status == :empty
      redirect_to boxes_path, notice: "✅ La boîte N°#{@box.id} est bien vidée !"
    else
      redirect_to box_path(@box)
    end
  end

  private

  def set_box
    @box = Box.find(params[:id])
  end

  def box_params
    params.require(:box).permit(:weight, :category_id, :electronic, :status)
  end
end
