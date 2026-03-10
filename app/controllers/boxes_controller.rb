class BoxesController < ApplicationController
  def index
    @boxes = Box.all
  end

  def show
    @box = box_set
  end

  def new
  end

  def create
  end

  def edit
    @box = Box.find(params[:id])
  end

  def update
  end

  def destroy
    @box = Box.find(params[:id])
    @box.destroy
    redirect_to boxes_path
  end

  private
  def box_set
    @box = Box.find(params[:id])
  end

  def box_params
    params.require(:box).permit(:name, :description)
  end
end
