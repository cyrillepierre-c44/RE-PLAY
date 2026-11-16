class Toy < ApplicationRecord
  belongs_to :box
  belongs_to :category
  has_many :actions, as: :actionable
  has_many :users, through: :actions
  has_many :quality_checks, dependent: :destroy
  # operator : le valorisateur, à qui les non-conformités sont comptées.
  # assignee : la personne à qui un admin a confié le jouet (opérateur absent).
  belongs_to :operator, class_name: "User", optional: true
  belongs_to :assignee, class_name: "User", optional: true
  # `:purge_later` (et non `:destroy`) est la valeur qui déclenche réellement
  # la suppression du fichier stocké (Cloudinary) quand le jouet est détruit ;
  # `:destroy` supprime seulement la ligne d'attachement et laissait le fichier
  # orphelin sur Cloudinary.
  has_one_attached :photo, dependent: :purge_later
  # Statuts : draft (brouillon) → pending (en attente de CQ) → market (prêt à la
  # vente). review = CQ refusé, à reprendre par l'opérateur ; arbitrage = refusé
  # une 2e fois, un admin doit choisir la destination. Destinations finales en
  # plus de market : vrac (pièces pour compléter d'autres jouets), don, suppr (rebut).
  enum :status, { pending: "pending", market: "market", suppr: "suppr", review: "review", draft: "draft",
                  arbitrage: "arbitrage", vrac: "vrac", don: "don" }
  include Draftable

  # Message posé dans admin_comment quand l'estimation IA est impossible (image refusée par
  # le filtre de sécurité du fournisseur) : la fiche affiche alors « prix à saisir » au lieu
  # du robot qui tourne, et l'opérateur fixe le prix à la main.
  # Valeur par défaut de `location` tant que le CQ n'a pas rangé le jouet.
  WAITING_LOCATION = "En attente de validation".freeze

  PRICING_BLOCKED_NOTE = "Prix IA impossible : image refusée par le filtre du fournisseur, prix à fixer à la main.".freeze

  def pricing_blocked? = admin_comment.to_s.include?(PRICING_BLOCKED_NOTE)

  def mark_pricing_blocked!
    return if pricing_blocked?

    note = [admin_comment.presence, PRICING_BLOCKED_NOTE].compact.join(" — ").first(255)
    update_columns(admin_comment: note, updated_at: Time.current)
  end
  after_initialize :set_default_status, if: :new_record?

  validates :status, presence: true
  validate :category_is_a_toy_category
  validate :discard_causes_are_known

  # Jouets dont `user` a la charge : les siens, sauf ceux confiés à quelqu'un d'autre.
  scope :held_by, ->(user) { where("COALESCE(toys.assignee_id, toys.operator_id) = ?", user.id) }

  def holder = assignee || operator

  # Non-conformité en cours : le dernier refus du CQ, tant que le jouet est
  # « CQ refusé » ou « à arbitrer ».
  def open_check
    return unless review? || arbitrage?

    quality_checks.select(&:refused?).max_by(&:id)
  end

  def discard_cause_labels = QualityCause.discard_labels(discard_causes)
  scope :waiting, -> { where(status: %i[pending review]) }
  scope :validated, -> { where(status: :market) }
  scope :deleted, -> { where(status: :suppr) }
  scope :sold, -> { where(sold: true) }
  scope :available, -> { where(sold: false) }
  private

  def discard_causes_are_known
    unknown = Array(discard_causes) - QualityCause::DISCARD_KEYS
    errors.add(:discard_causes, "inconnues : #{unknown.join(', ')}") if unknown.any?
  end

  # « Grosses pièces » décrit une caisse, pas un jouet.
  def category_is_a_toy_category
    errors.add(:category, "doit être la catégorie du jouet") if category&.mixed?
  end

  def set_default_status
    self.status ||= :pending
  end
end
