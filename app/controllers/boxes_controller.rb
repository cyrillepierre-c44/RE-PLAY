class BoxesController < ApplicationController
  before_action :set_box, only: %i[show edit update destroy]

  def index
    @boxes = policy_scope(Box)
  end

  def show
    authorize @box
  end

  def new
    @box = Box.new
    authorize @box
  end

  def create
    @box = Box.new(box_params)
    authorize @box
    if @box.save!
      Action.create!(user: current_user, actionable: @box, content: "#{current_user.email} à créé la boite n#{@box.id}")
      redirect_to boxes_path
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
    if @box.destroy
      redirect_to boxes_path, notice: "Demande supprimée avec succès."
      Action.create!(user: current_user, actionable: @box,
                     content: "#{current_user.email} à supprimé la boite n#{@box.id}")
    else
      redirect_to box_path(@box), alert: @box.errors.full_messages.to_sentence
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
