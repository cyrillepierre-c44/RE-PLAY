class ToysController < ApplicationController
  SYSTEM_PROMPT = "Tu es un expert en vente de jouet d'occasion reconditionnés issus de dons.
  Je travaille pour une entreprise Française, dans la zone euros, qui vend des jouets d'occasion et je souhaiterais
  savoir à quel prix je peux les vendre en tenant compte du prix du neuf et des prix pratiqués par la concurrence.
  Peux-tu m'aider à trouver le prix de vente de ce jouet d'occasion en te basant sur une fourchette de prix en euro.
  Merci de me faire une réponse en chiffres uniquement et sans lettres ni unité d'argent avec la valeur
  moyenne seulement. Par exemple : 10"

  before_action :set_toy, only: %i[show edit update destroy]
  before_action :box_find, only: %i[new create]

  def index
    @toys = Toy.all
    @toys = policy_scope(Toy)
  end

  def show
    authorize @toy
  end

  def new
    @toy = Toy.new
    authorize @toy
  end

  def create
    @toy = Toy.new(toy_params)
    authorize @toy
    authorize @box
    @toy.box = @box

    if @toy.save
      @ruby_llm_chat = RubyLLM.chat(model: "gpt-4o")
      @response = @ruby_llm_chat.ask(SYSTEM_PROMPT, with: { image: @toy.photo.url })
      @aiprice = @response.content.to_i
      @toy.update(price: @aiprice)

      Action.create!(user: current_user, actionable: @toy, content: "#{current_user.email} à créé le jouet n#{@toy.id}")
      redirect_to toys_path, notice: "Jouet créé avec succès.", status: :see_other
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @box = @toy.box
    authorize @toy
  end

  def update
    authorize @toy
    if @toy.update(toy_params)
      Action.create!(user: current_user, actionable: @toy,
                     content: "#{current_user.email} à updaté le jouet n#{@toy.id}")
      redirect_to toy_path(@toy), status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @toy
    if @toy.destroy
      redirect_to toys_path, notice: "Demande supprimée avec succès."
      Action.create!(user: current_user, actionable: @toy,
                     content: "#{current_user.email} à supprimé lejouet #{@toy.id}")
    else
      redirect_to toy_path(@toy), alert: @toy.errors.full_messages.to_sentence
    end
  end

  private

  def box_find
    @box = Box.find(params[:box_id])
  end

  def set_toy
    @toy = Toy.find(params[:id])
  end

  def toy_params
    params.require(:toy).permit(:category_id, :clean, :barcode, :complete, :playable, :photo, :price, :location)
  end
end
