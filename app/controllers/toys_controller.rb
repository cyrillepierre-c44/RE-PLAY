class ToysController < ApplicationController
  before_action :set_toy, only: %i[show edit update destroy verify confirm_verify restore]
  before_action :box_find, only: %i[new create]

  # SYSTEM_PROMPT = "Tu es un expert en vente de jouet d'occasion reconditionnés issus de dons.
  #   Je travaille pour une entreprise Française, dans la zone euros, qui vend des jouets d'occasion et je souhaiterais
  #   savoir à quel prix je peux les vendre en tenant compte du prix du neuf et des prix pratiqués par la concurrence.
  #   Peux-tu m'aider à trouver le prix de vente de ce jouet d'occasion en te basant obligatoirement sur
  #   l'état decrit ci-apres: Le jouet est #{system_prompt}.
  #   Merci de me faire une réponse en chiffres uniquement et sans lettres ni unité d'argent avec la valeur
  #   moyenne seulement. Par exemple : 10"

  def index
    base_scope = policy_scope(Toy)
    if params[:filter] == "validated"
      @toys = base_scope.validated
    elsif params[:filter] == "deleted"
      @toys = base_scope.deleted
    else
      @toys = base_scope.waiting
    end
  end

  def show
    authorize @toy
    @timeline = Action.where(actionable: @toy).includes(:user).order(created_at: :desc)
  end

  def new
    @toy = Toy.new(box: @box, category: @box.category)
    authorize @toy
    @toy.save(validate: false)
    Action.create!(user: current_user, actionable: @toy, content: "#{current_user.email} a débuté la création du jouet #{@toy.id}")
    redirect_to edit_toy_path(@toy, new: true), status: :see_other
  end

  def create
    @toy = Toy.new(toy_params)
    authorize @toy
    authorize @box
    @toy.box = @box

    if @toy.save
      PriceiaJob.perform_later(@toy.id, clean: @toy.clean, complete: @toy.complete, playable: @toy.playable)
      Action.create!(user: current_user, actionable: @toy, content: "#{current_user.email} à créé le jouet #{@toy.id}")
      redirect_to box_path(@box), notice: "Jouet créé avec succès.", status: :see_other
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
    if @toy.update(toy_params.merge(price: nil))
      PriceiaJob.perform_later(@toy.id, clean: @toy.clean, complete: @toy.complete, playable: @toy.playable)
      Action.create!(user: current_user, actionable: @toy,
                     content: "#{current_user.email} à updaté le jouet n#{@toy.id}")
      if params[:from_new] == "1"
        redirect_to box_path(@toy.box), notice: "Jouet créé avec succès.", status: :see_other
      else
        redirect_to toy_path(@toy), status: :see_other, notice: "modifié avec succès"
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @toy
    if @toy.update(status: :suppr)
      Action.create!(user: current_user, actionable: @toy,
                     content: "#{current_user.email} à supprimé le  jouet #{@toy.id}")
      redirect_to toys_path, notice: "Jouet supprimée avec succès."
    else
      redirect_to toy_path(@toy), alert: @toy.errors.full_messages.to_sentence
    end
  end

  def restore
    authorize @toy
    if @toy.update(status: :pending)
      Action.create!(user: current_user, actionable: @toy,
                     content: "#{current_user.email} a réintégré le jouet n°#{@toy.id} en attente")
      redirect_to toy_path(@toy), notice: "Jouet réintégré en attente."
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
    new_status = params[:status]

    if @toy.update(toy_params.merge(status: new_status))
      Action.create!(
        user: current_user,
        actionable: @toy,
        content: "#{current_user.email} a passé le jouet n#{@toy.id} en statut: #{new_status}"
      )
      if new_status == "market"
        redirect_to toys_path, notice: "Mis en vente de l'objet"
      else
        redirect_to toys_path, status: :see_other, notice: "Statut mis à jour : #{new_status}"
      end
    else
      @box = @toy.box
      render :verify, status: :unprocessable_entity
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
    params.require(:toy).permit(:category_id, :clean, :barcode, :complete, :playable, :photo, :price, :location,
                                :status)
  end
end
