class BoxesController < ApplicationController
  def index
    @boxes = policy_scope(Box)
  end

  def show
    @box = box_set
    authorize @box
  end

  def new
    @box = Box.new
    authorize @box
  end

  def create
    @box = Box.new(box_params)
    @box.user = current_user
    authorize @box
    if @box.save
      redirect_to boxes_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @box
    @box = box_set
  end

  def update
    authorize @box
    @box = box_set
    @box.update(box_params)
    redirect_to box_path(@box), status: :see_other
  end

  def destroy
    authorize @box
    @box = box_set
    if @box.destroy
      redirect_to boxes_path, notice: "Demande supprimée avec succès."
    else
      redirect_to box_path(@box), alert: @box.errors.full_messages.to_sentence
    end
  end

  private

  def box_set
    @box = Box.find(params[:id])
  end

  def box_params
    params.require(:box).permit(:weight, :category_id, :electronic, :user_id)
  end
end
