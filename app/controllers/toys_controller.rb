class ToysController < ApplicationController
  before_action :set_toy, only: %i[show edit update destroy]
  def index
    @toys = Toy.all
  end

  def show
    @boxes = Box.all
    @categories = Category.all
    @actions = Action.all
    @action = Action.new
    @action.toy_id = @toys.id
    @action.actionable_type = "Toy"
    @action.actionable_id = @toys.id
    @action.user_id = current_user.id
    @action.save
  end

  def new
    @toys = Toy.new
  end

  def create
    @toys = Toy.new(toy_params)
    if @toys.save
      redirect_to @toys
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @boxes = Box.all
    @categories = Category.all
    @actions = Action.all
    @action = Action.new
    @action.toy_id = @toys.id
    @action.actionable_type = "Toy"
    @action.actionable_id = @toys.id
    @action.user_id = current_user.id
    @action.save
    redirect_to toy_path(@toys)
  end

  def update
    if @toys.update(toy_params)
      redirect_to @toys
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @toys.destroy
    redirect_to toys_path, status: :see_other
  end

  private

  def set_toy
    @toys = Toy.find(params[:id])
  end

  def toy_params
    params.require(:toy).permit(:name, :box_id, :category_id)
  end
end
