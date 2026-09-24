class Toy < ApplicationRecord
  belongs_to :box
  belongs_to :category
  has_many :actions, as: :actionable
  has_many :users, through: :actions
  # `:purge_later` (et non `:destroy`) est la valeur qui déclenche réellement
  # la suppression du fichier stocké (Cloudinary) quand le jouet est détruit ;
  # `:destroy` supprime seulement la ligne d'attachement et laissait le fichier
  # orphelin sur Cloudinary.
  has_one_attached :photo, dependent: :purge_later
  enum :status, { pending: "pending", market: "market", suppr: "suppr", review: "review" }

  # Message posé dans admin_comment quand l'estimation IA est impossible (image refusée par
  # le filtre de sécurité du fournisseur) : la fiche affiche alors « prix à saisir » au lieu
  # du robot qui tourne, et l'opérateur fixe le prix à la main.
  PRICING_BLOCKED_NOTE = "Prix IA impossible : image refusée par le filtre du fournisseur, prix à fixer à la main.".freeze

  def pricing_blocked? = admin_comment.to_s.include?(PRICING_BLOCKED_NOTE)

  def mark_pricing_blocked!
    return if pricing_blocked?
    note = [ admin_comment.presence, PRICING_BLOCKED_NOTE ].compact.join(" — ").first(255)
    update_columns(admin_comment: note, updated_at: Time.current)
  end
  after_initialize :set_default_status, if: :new_record?

  validates :status, presence: true
  scope :waiting, -> { where(status: %i[pending review]) }
  scope :validated, -> { where(status: :market) }
  scope :deleted, -> { where(status: :suppr) }
  scope :sold, -> { where(sold: true) }
  scope :available, -> { where(sold: false) }
  private

  def set_default_status
    self.status ||= :pending
  end
end
