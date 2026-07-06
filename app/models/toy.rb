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
