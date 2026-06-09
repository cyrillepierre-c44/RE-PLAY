class ToysController < ApplicationController
  before_action :set_toy, only: %i[show edit update destroy verify confirm_verify restore toggle_sold]
  before_action :box_find, only: %i[new create quick_discard]

  # SYSTEM_PROMPT = "Tu es un expert en vente de jouet d'occasion reconditionnés issus de dons.
  #   Je travaille pour une entreprise Française, dans la zone euros, qui vend des jouets d'occasion et je souhaiterais
  #   savoir à quel prix je peux les vendre en tenant compte du prix du neuf et des prix pratiqués par la concurrence.
  #   Peux-tu m'aider à trouver le prix de vente de ce jouet d'occasion en te basant obligatoirement sur
  #   l'état decrit ci-apres: Le jouet est #{system_prompt}.
  #   Merci de me faire une réponse en chiffres uniquement et sans lettres ni unité d'argent avec la valeur
  #   moyenne seulement. Par exemple : 10"

  def index
    base_scope = policy_scope(Toy)
    base_scope = base_scope.where(category_id: params[:category_id]) if params[:category_id].present?
    if params[:q].present?
      num = params[:q].to_s.gsub(/\D/, '')
      @toys = num.present? ? base_scope.where(id: num) : base_scope.none
    elsif params[:filter] == "validated"
      @toys = base_scope.validated.available.order(created_at: :desc)
    elsif params[:filter] == "sold"
      @toys = base_scope.validated.sold.order(created_at: :desc)
    elsif params[:filter] == "deleted"
      @toys = base_scope.deleted.order(created_at: :desc)
    else
      @toys = base_scope.waiting.order(
        Arel.sql("CASE WHEN toys.status = 'review' THEN 0 ELSE 1 END"),
        created_at: :desc
      )
    end
    own = current_user.admin? ? Toy : Toy.where(id: Action.where(actionable_type: "Toy", user: current_user).select(:actionable_id))
    @count_scope = params[:category_id].present? ? own.where(category_id: params[:category_id]) : own
    @categories = Category.all.order(:name)
  end

  def show
    authorize @toy
    @timeline = Action.where(actionable: @toy).includes(:user).order(created_at: :desc)
  end

  def quick_discard
    c = params[:toy] || {}
    @toy = Toy.new(
      box: @box, category: @box.category, status: :suppr,
      french:        c[:french].to_s == "1",
      ce_mark:       c[:ce_mark].to_s == "1",
      safe:          c[:safe].to_s == "1",
      clean:         c[:clean].to_s == "1",
      complete:      c[:complete].to_s == "1",
      playable:      c[:playable].to_s == "1",
      operator_note: c[:operator_note].presence
    )
    authorize @toy
    @toy.save(validate: false)
    Action.create!(user: current_user, actionable: @toy,
                   content: "#{current_user.email} a jeté directement le jouet J#{@toy.id}")
    {
      french:   "NC:français",
      ce_mark:  "NC:CE/marque",
      safe:     "NC:sécurité",
      clean:    "NC:propreté",
      complete: "NC:complet",
      playable: "NC:jouable"
    }.each do |field, nc_key|
      unless @toy.send(field)
        Action.create!(user: current_user, actionable: @toy,
                       content: "[#{nc_key}] #{current_user.email} a rejeté #{nc_key.sub('NC:', '')} du jouet J#{@toy.id}")
      end
    end
    redirect_to box_path(@box), notice: "Jouet jeté.", status: :see_other
  end

  def new
    @toy = Toy.new(box: @box, category: @box.category)
    authorize @toy
    @toy.save(validate: false)
    Action.create!(user: current_user, actionable: @toy, content: "#{current_user.email} a débuté la création du jouet J#{@toy.id}")
    redirect_to edit_toy_path(@toy, new: true), status: :see_other
  end

  def create
    @toy = Toy.new(toy_params)
    authorize @toy
    authorize @box
    @toy.box = @box

    if @toy.save
      PriceiaJob.perform_later(@toy.id, french: @toy.french, ce_mark: @toy.ce_mark, safe: @toy.safe, clean: @toy.clean, complete: @toy.complete, playable: @toy.playable)
      Action.create!(user: current_user, actionable: @toy, content: "#{current_user.email} a créé le jouet J#{@toy.id}")
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
      PriceiaJob.perform_later(@toy.id, french: @toy.french, ce_mark: @toy.ce_mark, safe: @toy.safe, clean: @toy.clean, complete: @toy.complete, playable: @toy.playable)
      Action.create!(user: current_user, actionable: @toy,
                     content: "#{current_user.email} a modifié le jouet J#{@toy.id}")
      if params[:from_new] == "1"
        redirect_to toy_path(@toy, back_box: @toy.box_id), notice: "Jouet créé avec succès.", status: :see_other
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
                     content: "#{current_user.email} a supprimé le jouet J#{@toy.id}")
      redirect_to toys_path(filter: "deleted"), notice: "Jouet J#{@toy.id} supprimé."
    else
      redirect_to toy_path(@toy), alert: @toy.errors.full_messages.to_sentence
    end
  end

  def restore
    authorize @toy
    if @toy.update(status: :pending)
      Action.create!(user: current_user, actionable: @toy,
                     content: "#{current_user.email} a réintégré le jouet J#{@toy.id} en attente")
      redirect_to toys_path, notice: "Jouet J#{@toy.id} remis en attente."
    else
      redirect_to toy_path(@toy), alert: @toy.errors.full_messages.to_sentence
    end
  end

  def toggle_sold
    authorize @toy
    @toy.update!(sold: !@toy.sold)
    label = @toy.sold? ? "marqué le jouet J#{@toy.id} comme vendu" : "marqué le jouet J#{@toy.id} comme disponible"
    Action.create!(user: current_user, actionable: @toy, content: "#{current_user.email} a #{label}")
    redirect_to toy_path(@toy), notice: @toy.sold? ? "Jouet J#{@toy.id} marqué comme vendu." : nil
  end

  def purge_deleted
    authorize Toy, :purge_deleted?
    toys = Toy.deleted
    toys.each { |toy| Action.where(actionable: toy).destroy_all }
    toys.destroy_all
    redirect_to toys_path(filter: "deleted"), notice: "Tous les jouets supprimés ont été définitivement effacés."
  end

  def verify
    @box = @toy.box
    authorize @toy
  end

  def confirm_verify
    authorize @toy
    new_status = params[:status]

    if @toy.update(verify_params.merge(status: new_status))
      Action.create!(
        user: current_user,
        actionable: @toy,
        content: "#{current_user.email} a passé le jouet J#{@toy.id} en statut: #{new_status}"
      )
      log_nonconformities
      if new_status == "market"
        redirect_to toys_path, notice: "Mise en vente de l'objet"
      else
        redirect_to toys_path, status: :see_other, notice: "Statut mis à jour : #{new_status}"
      end
    else
      @box = @toy.box
      render :verify, status: :unprocessable_entity
    end
  end

  private

  def log_nonconformities
    bool_nc = {
      french:   "NC:français",
      ce_mark:  "NC:CE/marque",
      safe:     "NC:sécurité",
      clean:    "NC:propreté",
      complete: "NC:complet",
      playable: "NC:jouable"
    }
    if params[:status] == "review"
      # Revaloriser : tous les critères actuellement à false sont des motifs de NC
      bool_nc.each do |attr, nc_key|
        next if @toy.send(attr)
        Action.create!(user: current_user, actionable: @toy,
                       content: "[#{nc_key}] #{current_user.email} a renvoyé #{nc_key.sub('NC:', '')} du jouet J#{@toy.id}")
      end
    else
      # Mise en vente : on logue uniquement les critères corrigés (changés)
      bool_nc.merge(category_id: "NC:catégorie").each do |attr, nc_key|
        next unless @toy.saved_change_to_attribute?(attr)
        Action.create!(user: current_user, actionable: @toy,
                       content: "[#{nc_key}] #{current_user.email} a corrigé #{nc_key.sub('NC:', '')} du jouet J#{@toy.id}")
      end
    end
  end

  def box_find
    @box = Box.find(params[:box_id])
  end

  def set_toy
    @toy = Toy.find(params[:id])
  end

  def toy_params
    permitted = params.require(:toy).permit(:category_id, :french, :ce_mark, :safe, :clean, :barcode, :complete, :playable, :photo, :location, :status, :operator_note)
    current_user.admin? ? permitted.except(:operator_note) : permitted
  end

  def verify_params
    params.require(:toy).permit(:category_id, :french, :ce_mark, :safe, :clean, :barcode, :complete, :playable, :photo, :price, :location,
                                :status, :admin_comment)
  end
end
