class BoxesController < ApplicationController
  def index
    @boxes = Box.all
  end

  def show
    @box = box_set
  end

  def new
    @box = Box.new
  end

  def create
    @box = Box.new(box_params)
    if @box.save
      redirect_to boxes_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @box = box_set
  end

  def update
    @box = box_set
    @box.update(box_params)
    redirect_to box_path(@box), status: :see_other
  end

  def destroy
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
    params.require(:box).permit(:weight, :category_id, :electronic)
  end
end
