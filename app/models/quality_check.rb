# Une décision du contrôle qualité (CQ) sur un jouet. Voir la migration
# CreateQualityChecks et QualityControl (qui les crée).
#
# round    : 1 = premier contrôle, 2 = contrôle après revalorisation,
#            3 = arbitrage par un admin après un 2e refus.
# decision : accepted (mise en vente), refused (non-conformité), ou une
#            destination finale décidée par l'admin (vrac, don, discarded).
class QualityCheck < ApplicationRecord
  DECISIONS = %w[accepted refused vrac don discarded].freeze
  ARBITRATION_ROUND = 3

  belongs_to :toy
  belongs_to :operator, class_name: "User", optional: true
  belongs_to :checker, class_name: "User", optional: true

  validates :round, inclusion: { in: 1..ARBITRATION_ROUND }
  validates :decision, inclusion: { in: DECISIONS }
  validate :causes_are_known
  validates :causes, presence: { message: "à cocher : au moins un problème" }, if: :refused?
  validates :cq_comment, presence: { message: "obligatoire" }, if: :comment_required?

  scope :refused, -> { where(decision: "refused") }
  scope :rated, -> { where(decision: %w[accepted refused]) }
  # Non-conformité ouverte : refusée au 1er tour, pas encore retraitée par l'opérateur.
  scope :awaiting_rework, -> { refused.where(round: 1, reworked_at: nil, resolved_at: nil) }
  scope :unresolved, -> { refused.where(resolved_at: nil) }

  def refused? = decision == "refused"
  def accepted? = decision == "accepted"

  # Commentaire CQ obligatoire à chaque refus et à tout ce qui n'est pas une
  # validation du 1er coup (2e tour, arbitrage, vrac, don, rebut).
  def comment_required?
    !(accepted? && round == 1)
  end

  # Jours ouvrés depuis le refus (jusqu'au retraitement s'il a eu lieu).
  def working_days_open(now = Time.current)
    WorkingDays.elapsed(created_at, reworked_at || resolved_at || now)
  end

  # En retard (bandeau rouge) : plus de `threshold` jours ouvrés sans retraitement.
  def late?(threshold = QualitySetting.current.red_after_days)
    working_days_open > threshold
  end

  def cause_labels = QualityCause.cq_labels(causes)

  private

  def causes_are_known
    unknown = Array(causes) - QualityCause::CQ_KEYS
    errors.add(:causes, "inconnues : #{unknown.join(', ')}") if unknown.any?
  end
end
