class ToysController < ApplicationController
  before_action :set_toy, only: %i[show edit update destroy verify confirm_verify]
  before_action :box_find, only: %i[new create]

  # SYSTEM_PROMPT = "Tu es un expert en vente de jouet d'occasion reconditionnés issus de dons.
  #   Je travaille pour une entreprise Française, dans la zone euros, qui vend des jouets d'occasion et je souhaiterais
  #   savoir à quel prix je peux les vendre en tenant compte du prix du neuf et des prix pratiqués par la concurrence.
  #   Peux-tu m'aider à trouver le prix de vente de ce jouet d'occasion en te basant obligatoirement sur
  #   l'état decrit ci-apres: Le jouet est #{system_prompt}.
  #   Merci de me faire une réponse en chiffres uniquement et sans lettres ni unité d'argent avec la valeur
  #   moyenne seulement. Par exemple : 10"

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
      chat_response
      Action.create!(user: current_user, actionable: @toy, content: "#{current_user.email} à créé le jouet #{@toy.id}")
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
      chat_response
      Action.create!(user: current_user, actionable: @toy,
                     content: "#{current_user.email} à updaté le jouet n#{@toy.id}")
      redirect_to toy_path(@toy), status: :see_other, notice: "modifié avec succès"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @toy
    if @toy.destroy
      redirect_to toys_path, notice: "Jouet supprimée avec succès."
      Action.create!(user: current_user, actionable: @toy,
                     content: "#{current_user.email} à supprimé le  jouet #{@toy.id}")
    else
      redirect_to toy_path(@toy), alert: @toy.errors.full_messages.to_sentence
    end
  end

  def verify
    @box = @toy.box
    authorize @toy
  end

  def confirm_verify
    authorize @toy
    if @toy.update(toy_params)
      Action.create!(user: current_user, actionable: @toy,
                     content: "#{current_user.email} a validé le contrôle du jouet n#{@toy.id}")
      redirect_to toy_path(@toy), status: :see_other, notice: "contrôle validé !"
    else
      @box = @toy.box
      render :verify, status: :unprocessable_entity
    end
  end

  private

  def chat_response
    @ruby_llm_chat = RubyLLM.chat(model: "gpt-4o")
    @response = @ruby_llm_chat.ask(system_prompt, with: { image: @toy.photo.url })
    @aiprice = @response.content.to_i
    @toy.update(price: @aiprice)
  end

  def system_prompt
    boolean = ActiveModel::Type::Boolean.new
    "Tu es un expert en vente de jouet d'occasion reconditionnés par des ateliers francais.
    Je travaille pour une entreprise Française, dans la zone euros, qui reconditionne et vend des jouets d'occasion
    et je souhaite savoir à quel prix je peux les vendre en tenant compte des prix pratiqués par la concurrence
    pour le même jouet ou des jouets similaires qui lui ressemble.
    Peux-tu m'aider à trouver le prix de vente de ce jouet d'occasion en te basant aussi sur
    l'état decrit ci-apres: Le jouet est
    #{boolean.cast(params[:toy][:clean]) ? 'propre' : 'sale'},
    #{boolean.cast(params[:toy][:complete]) ? 'complet' : 'incomplet'} et
    #{boolean.cast(params[:toy][:playable]) ? 'fonctionnel' : 'non fonctionnel'}.
    Merci de me faire une réponse en chiffres uniquement et sans lettres ni unité d'argent avec la valeur
    moyenne seulement. Par exemple : 10"
  end

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
