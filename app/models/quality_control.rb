# Applique une décision du contrôle qualité à un jouet (écran « Contrôle
# qualité » des admins) : met à jour le jouet, enregistre le QualityCheck du tour
# et ferme les non-conformités précédentes. Tout ou rien.
#
# Parcours : 1er tour → mise en vente, ou refus (jouet « CQ refusé », à
# reprendre par l'opérateur). Après retraitement, 2e tour → mise en vente, ou
# 2e refus : la boucle s'arrête, le jouet passe « À arbitrer » et un admin
# choisit sa destination (vendre en l'état, vrac, don, rebut). Vrac, don et
# rebut peuvent aussi être décidés dès le 1er tour.
class QualityControl
  # valeur du bouton → [décision enregistrée, statut du jouet]
  OUTCOMES = {
    "market" => %w[accepted market],
    "review" => %w[refused review],
    "vrac" => %w[vrac vrac],
    "don" => %w[don don],
    "suppr" => %w[discarded suppr]
  }.freeze

  attr_reader :toy, :check

  def initialize(toy, checker:)
    @toy = toy
    @checker = checker
  end

  # Tour du prochain contrôle.
  def round
    return QualityCheck::ARBITRATION_ROUND if toy.arbitrage?

    [toy.quality_checks.rated.count + 1, 2].min
  end

  def comment_required_to_accept? = round > 1

  def decide(outcome:, causes: [], comment: nil, attributes: {})
    decision, status = OUTCOMES.fetch(outcome) { return add_error("Décision inconnue.") && false }
    if decision == "refused" && toy.arbitrage?
      add_error("Un jouet à arbitrer ne peut plus être renvoyé en revalorisation.")
      return false
    end

    current_round = round
    status = "arbitrage" if decision == "refused" && current_round == 2
    record = !(decision == "accepted" && toy.market?) # simple correction d'un jouet déjà en vente

    Toy.transaction do
      @check = build_check(decision, current_round, causes, comment) if record
      toy.assign_attributes(attributes.merge(status: status))
      toy.operator_note = nil if decision == "refused" # libère la note du tour suivant
      saved = toy.valid? && (!record || @check.valid?)
      copy_check_errors if record
      if status == "market" && (toy.location.blank? || toy.location == Toy::WAITING_LOCATION)
        toy.errors.add(:base, "L'emplacement est obligatoire pour la mise en vente")
        saved = false
      end
      raise ActiveRecord::Rollback unless saved

      toy.quality_checks.unresolved.update_all(resolved_at: Time.current) if record
      toy.save!
      @check&.save!
    end
    toy.quality_checks.reset if record
    toy.errors.empty?
  end

  private

  def build_check(decision, current_round, causes, comment)
    # QualityCheck.new (et non toy.quality_checks.build) : un contrôle refusé à la
    # validation ne doit pas rester accroché à l'historique affiché du jouet.
    QualityCheck.new(
      toy: toy, round: current_round, decision: decision, checker: @checker, operator_id: toy.operator_id,
      causes: decision == "refused" ? Array(causes).compact_blank : [],
      cq_comment: comment.to_s.strip.presence, operator_comment: toy.operator_note.presence
    )
  end

  def copy_check_errors
    @check.errors.each { |error| toy.errors.add(:base, "#{human(error.attribute)} #{error.message}") }
  end

  def human(attribute)
    { causes: "Problèmes détectés", cq_comment: "Commentaire du contrôle qualité" }.fetch(attribute, attribute.to_s)
  end

  def add_error(message)
    toy.errors.add(:base, message)
  end
end
