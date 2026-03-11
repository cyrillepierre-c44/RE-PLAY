class ToysController < ApplicationController
  before_action :set_toy, only: %i[show edit update destroy]
  def index
    @toys = Toy.all
  end

  def show
    @boxes = Box.all
    @categories = Category.all
    @actions = Action.all
    # @action = Action.new
    # @action.toy_id = @toys.id
    # @action.actionable_type = "Toy"
    # @action.actionable_id = @toys.id
    # @action.user_id = current_user.id
    # @action.save
  end


  def new
    @toy = Toy.new
    @box = Box.find(params[:box_id])
  end

  def create
    @box = Box.find(params[:box_id])
    @toy = Toy.new(toy_params)
    @toy.box = @box

    if @toy.save
      redirect_to toys_path, notice: "Jouet créé avec succès.", status: :see_other
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @box = @toy.box
  end

  def update
    if @toy.update(toy_params)
      redirect_to toy_path(@toy), status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @toy.destroy
      redirect_to toys_path, notice: "Demande supprimée avec succès."
    else
      redirect_to toy_path(@toy), alert: @toy.errors.full_messages.to_sentence
    end
  end

  private

  def set_toy
    @toy = Toy.find(params[:id])
  end

  def toy_params
    params.require(:toy).permit(:category_id, :clean, :barcode, :complete, :playable, :photo, :price, :location)
  end
end
