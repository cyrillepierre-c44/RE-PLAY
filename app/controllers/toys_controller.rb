class ToysController < ApplicationController
  before_action :set_toy, only: %i[show edit update destroy verify confirm_verify restore toggle_sold refresh_price reassign]
  before_action :box_find, only: %i[new create quick_discard]
  helper_method :new_flow?

  # SYSTEM_PROMPT = "Tu es un expert en vente de jouet d'occasion reconditionnés issus de dons.
  #   Je travaille pour une entreprise Française, dans la zone euros, qui vend des jouets d'occasion et je souhaiterais
  #   savoir à quel prix je peux les vendre en tenant compte du prix du neuf et des prix pratiqués par la concurrence.
  #   Peux-tu m'aider à trouver le prix de vente de ce jouet d'occasion en te basant obligatoirement sur
  #   l'état decrit ci-apres: Le jouet est #{system_prompt}.
  #   Merci de me faire une réponse en chiffres uniquement et sans lettres ni unité d'argent avec la valeur
  #   moyenne seulement. Par exemple : 10"

  def index
    # includes/with_attached_photo : la vue lit toy.category et toy.photo pour
    # chaque carte — sans préchargement c'est 3 requêtes par jouet (N+1).
    base_scope = policy_scope(Toy).not_draft.includes(:category, :quality_checks).with_attached_photo
    base_scope = base_scope.where(category_id: params[:category_id]) if params[:category_id].present?
    if params[:q].present?
      num = params[:q].to_s.gsub(/\D/, '')
      @toys = num.present? ? base_scope.where(id: num) : base_scope.none
      if @toys.one?
        t = @toys.first
        @active_filter = if t.suppr? then "deleted"
                         elsif t.market? && t.sold? then "sold"
                         elsif t.market? then "validated"
                         end
      end
    elsif params[:filter] == "validated"
      @toys = base_scope.validated.available.order(created_at: :desc)
    elsif params[:filter] == "sold"
      @toys = base_scope.validated.sold.order(created_at: :desc)
    elsif params[:filter] == "deleted"
      @toys = base_scope.deleted.order(created_at: :desc)
    elsif params[:filter] == "review"
      # « À reprendre » : les CQ refusés dont l'utilisateur a la charge (tous pour
      # l'admin), le plus ancien refus en premier (FIFO).
      scope = current_user.admin? ? base_scope.review : base_scope.review.held_by(current_user)
      @toys = scope.sort_by { |toy| toy.open_check&.created_at || toy.updated_at }
    elsif %w[arbitrage vrac don].include?(params[:filter])
      @toys = base_scope.where(status: params[:filter]).order(updated_at: :asc)
    else
      @toys = base_scope.waiting.order(
        Arel.sql("CASE WHEN toys.status = 'review' THEN 0 ELSE 1 END"),
        created_at: :desc
      )
    end
    own = if current_user.admin?
            Toy
          else
            Toy.where(id: Action.where(actionable_type: "Toy",
                                       user: current_user).select(:actionable_id))
          end
    @count_scope = params[:category_id].present? ? own.where(category_id: params[:category_id]) : own
    @categories = Category.for_toys.order(:name)
    @drafts = policy_scope(Toy).draft.order(:id)
    rework = current_user.admin? ? Toy.review : Toy.review.held_by(current_user)
    @rework_count = rework.count
    red_after = QualitySetting.current.red_after_days
    @rework_late = rework.includes(:quality_checks).any? { |toy| toy.open_check&.late?(red_after) }
    @missing_price_count = current_user.admin? ? Toy.waiting.where(price: nil).joins(:photo_attachment).count : 0
    session.delete(:price_refresh_total) # ancien format
    refresh = session[:price_refresh]
    return unless current_user.admin? && refresh.present?

    @price_refresh_total = refresh["total"].to_i
    if @missing_price_count.zero?
      session.delete(:price_refresh)
      flash.now[:notice] = "Prix recalculé pour #{@price_refresh_total} jouet(s) !"
      @price_refresh_total = nil
    elsif refresh["started_at"].to_i < 30.minutes.ago.to_i
      # calcul manifestement abandonné (jobs en échec) : on rend la main
      session.delete(:price_refresh)
      @price_refresh_total = nil
    end
  end

  def show
    authorize @toy
    # Un brouillon n'a pas de fiche : on reprend sa création là où elle s'est arrêtée.
    return redirect_to edit_toy_path(@toy, new: true) if @toy.draft?

    @timeline = Action.where(actionable: @toy).includes(:user).order(created_at: :desc)
  end

  def quick_discard
    # Jet à l'entrée de la VALO : la ou les causes disent pourquoi (cf. QualityCause::DISCARD).
    # Celles marquées `tri` comptent contre le Bon du 1er coup du TRI.
    c = params[:toy] || {}
    causes = Array(c[:discard_causes]).compact_blank & QualityCause::DISCARD_KEYS
    # Destination choisie par l'opérateur : rebut (par défaut), don (ex. Armée du Salut) ou vrac.
    status = DISCARD_DESTINATIONS.fetch(c[:destination].to_s, "suppr")
    @toy = Toy.new(box: @box, category: @box.toy_category, status: status, operator: current_user,
                   discard_causes: causes, operator_note: c[:operator_note].presence)
    authorize @toy
    return redirect_to box_path(@box), alert: "Choisissez au moins une raison pour jeter le jouet.", status: :see_other if causes.empty?

    @toy.save(validate: false)
    Action.create!(user: current_user, actionable: @toy,
                   content: "#{current_user.email} a écarté directement le jouet J#{@toy.id} " \
                            "(#{DISCARD_LABELS[status]}) : #{@toy.discard_cause_labels.join(', ')}")
    redirect_to box_path(@box), notice: "Jouet J#{@toy.id} : #{DISCARD_LABELS[status]}.", status: :see_other
  end

  def new
    # Brouillon : le numéro J est réservé tout de suite, la fiche ne devient un vrai
    # jouet « en attente » qu'au premier enregistrement du formulaire (cf. Draftable).
    @toy = Toy.new(box: @box, category: @box.toy_category, status: :draft, operator: current_user)
    authorize @toy
    @toy.save(validate: false)
    Action.create!(user: current_user, actionable: @toy,
                   content: "#{current_user.email} a débuté la création du jouet J#{@toy.id}")
    redirect_to edit_toy_path(@toy, new: true), status: :see_other
  end

  def create
    @toy = Toy.new(toy_params)
    authorize @toy
    authorize @box
    @toy.box = @box
    @toy.operator ||= current_user

    if @toy.save
      PriceiaJob.perform_later(@toy.id, french: @toy.french, ce_mark: @toy.ce_mark, safe: @toy.safe, clean: @toy.clean,
                                        complete: @toy.complete, playable: @toy.playable)
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
    was_draft = @toy.draft?
    # Enregistrer un jouet « CQ refusé », c'est le retraiter : il repart en attente
    # de contrôle (2e tour) et le délai de la non-conformité s'arrête là.
    reworked = @toy.review? ? @toy.open_check : nil
    @toy.status = :pending if was_draft || @toy.review?
    if @toy.update(toy_params.merge(price: nil))
      reworked&.update!(reworked_at: Time.current)
      PriceiaJob.perform_later(@toy.id, french: @toy.french, ce_mark: @toy.ce_mark, safe: @toy.safe, clean: @toy.clean,
                                        complete: @toy.complete, playable: @toy.playable)
      Action.create!(user: current_user, actionable: @toy,
                     content: "#{current_user.email} a #{reworked ? 'retraité' : 'modifié'} le jouet J#{@toy.id}")
      if reworked
        redirect_to toys_path(filter: "review"), notice: "Jouet J#{@toy.id} renvoyé au contrôle qualité.", status: :see_other
      elsif params[:from_new] == "1"
        redirect_to toy_path(@toy, back_box: @toy.box_id), notice: "Jouet créé avec succès.", status: :see_other
      else
        redirect_to toy_path(@toy), status: :see_other, notice: "modifié avec succès"
      end
    else
      @toy.status = :draft if was_draft
      @toy.status = :review if reworked
      @box = @toy.box
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @toy
    # Brouillon (flèche retour du formulaire de création, ou poubelle « à terminer ») :
    # suppression définitive, sans passer par la corbeille.
    if @toy.draft?
      box = @toy.box
      @toy.discard_draft!
      return redirect_to box_path(box), status: :see_other
    end

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

  def refresh_price
    authorize @toy
    return redirect_to toy_path(@toy), alert: "Impossible de calculer le prix : le jouet n'a pas de photo." unless @toy.photo.attached?

    @toy.update(price: nil)
    PriceiaJob.perform_later(@toy.id, french: @toy.french, ce_mark: @toy.ce_mark, safe: @toy.safe, clean: @toy.clean,
                                      complete: @toy.complete, playable: @toy.playable)
    Action.create!(user: current_user, actionable: @toy,
                   content: "#{current_user.email} a relancé le calcul du prix du jouet J#{@toy.id}")
    redirect_to toy_path(@toy), notice: "Nouveau calcul du prix en cours pour le jouet J#{@toy.id}…", status: :see_other
  end

  def refresh_missing_prices
    authorize Toy, :refresh_missing_prices?
    toys = Toy.waiting.where(price: nil).joins(:photo_attachment)
    session[:price_refresh] = { "total" => toys.count, "started_at" => Time.current.to_i }
    toys.find_each do |toy|
      PriceiaJob.perform_later(toy.id, french: toy.french, ce_mark: toy.ce_mark, safe: toy.safe, clean: toy.clean,
                                       complete: toy.complete, playable: toy.playable)
      Action.create!(user: current_user, actionable: toy,
                     content: "#{current_user.email} a relancé le calcul du prix du jouet J#{toy.id}")
    end
    redirect_to toys_path, status: :see_other
  end

  def refresh_prices_status
    authorize Toy, :refresh_prices_status?
    render json: { remaining: Toy.waiting.where(price: nil).joins(:photo_attachment).count }
  end

  def cancel_price_refresh
    authorize Toy, :cancel_price_refresh?
    cancelled = 0
    SolidQueue::Job.where(class_name: "PriceiaJob", finished_at: nil).find_each do |job|
      job.discard
      cancelled += 1
    rescue StandardError
      # job déjà pris par un worker : il terminera son calcul
    end
    session.delete(:price_refresh)
    redirect_to toys_path, notice: "Calcul des prix arrêté (#{cancelled} en attente annulé(s)).", status: :see_other
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
    @control = QualityControl.new(@toy, checker: current_user)
  end

  def confirm_verify
    authorize @toy
    @control = QualityControl.new(@toy, checker: current_user)
    was_arbitrage = @toy.arbitrage?
    cq = params[:quality] || {}

    attributes = verify_params
    attributes.delete(:location) if attributes[:location].blank? # champ vidé à l'affichage tant qu'il n'est pas fixé

    if @control.decide(outcome: params[:status].to_s, causes: cq[:causes], comment: cq[:comment],
                       attributes: attributes)
      Action.create!(user: current_user, actionable: @toy,
                     content: "#{current_user.email} a passé le jouet J#{@toy.id} en statut: #{@toy.status}")
      log_quality_decision
      back = was_arbitrage ? toys_path(filter: "arbitrage") : toys_path
      redirect_to back, status: :see_other, notice: QUALITY_NOTICES.fetch(@toy.status, "Statut mis à jour.")
    else
      @toy.restore_attributes(%i[status operator_note])
      @quality_input = { causes: Array(cq[:causes]), comment: cq[:comment] }
      @box = @toy.box
      render :verify, status: :unprocessable_entity
    end
  end

  # Un admin confie le jouet à un autre opérateur (opérateur absent). La
  # non-conformité reste comptée au valorisateur d'origine.
  def reassign
    authorize @toy
    user = User.find(params[:user_id])
    @toy.update_columns(assignee_id: user.id == @toy.operator_id ? nil : user.id, updated_at: Time.current)
    Action.create!(user: current_user, actionable: @toy,
                   content: "#{current_user.email} a confié le jouet J#{@toy.id} à #{user.email}")
    redirect_back fallback_location: toy_path(@toy), notice: "Jouet J#{@toy.id} confié à #{user.email}.", status: :see_other
  end

  # « Écarter directement » un jouet à l'entrée de la VALO : destination → statut.
  DISCARD_DESTINATIONS = { "rebut" => "suppr", "don" => "don", "vrac" => "vrac" }.freeze
  DISCARD_LABELS = { "suppr" => "rebut", "don" => "don", "vrac" => "vrac" }.freeze

  QUALITY_NOTICES = {
    "market" => "Mise en vente de l'objet",
    "review" => "Jouet renvoyé en revalorisation.",
    "arbitrage" => "2e refus : le jouet est à arbitrer.",
    "vrac" => "Jouet envoyé au vrac.",
    "don" => "Jouet envoyé aux dons.",
    "suppr" => "Jouet jeté."
  }.freeze

  private

  # Vrai pendant la création d'un jouet (new → edit?new=true), y compris quand le
  # formulaire est réaffiché après une erreur : seul le champ caché from_new
  # revient alors, et sans lui la page basculait en « Modifier le jouet ».
  def new_flow?
    params[:new].present? || params[:from_new] == "1" || @toy&.draft?
  end

  def log_quality_decision
    check = @control.check
    return unless check

    detail = [check.cause_labels.join(", ").presence, check.cq_comment].compact.join(" — ")
    verb = check.refused? ? "a refusé au CQ" : "a contrôlé"
    label = "#{verb} le jouet J#{@toy.id} (tour #{check.round})"
    Action.create!(user: current_user, actionable: @toy,
                   content: "[CQ] #{current_user.email} #{label}#{" : #{detail}" if detail.present?}".first(1000))
  end

  def box_find
    @box = Box.find(params[:box_id])
  end

  def set_toy
    @toy = Toy.find(params[:id])
  end

  def toy_params
    # :status volontairement exclu — le cycle de vie (pending/market/suppr/review)
    # ne passe que par les actions dédiées (verify, destroy…), jamais par le formulaire.
    permitted = params.require(:toy).permit(:category_id, :french, :ce_mark, :safe, :clean, :barcode, :complete,
                                            :playable, :photo, :location, :operator_note)
    current_user.admin? ? permitted.except(:operator_note) : permitted
  end

  def verify_params
    # :status exclu — la décision passe par QualityControl (bouton `status` hors `toy`).
    params.require(:toy).permit(:category_id, :french, :ce_mark, :safe, :clean, :barcode, :complete, :playable, :photo,
                                :price, :location)
  end
end
