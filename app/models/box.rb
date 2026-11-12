class Box < ApplicationRecord
  belongs_to :category
  has_many :actions, as: :actionable
  has_many :toys, dependent: :destroy

  enum :status, { pending: "pending", empty: "empty", suppr: "suppr", draft: "draft" }
  include Draftable

  after_initialize :set_default_status, if: :new_record?

  validates :status, presence: true
  scope :active, -> { where(status: :pending) }
  scope :deleted, -> { where(status: :suppr) }

  # Catégorie donnée par défaut à un jouet créé depuis cette caisse : celle de la
  # caisse, sauf pour une caisse mélangée (« Grosses pièces ») où chaque jouet
  # a sa propre catégorie, à choisir par l'opérateur.
  def toy_category
    category unless category&.mixed?
  end

  private

  def set_default_status
    self.status ||= :pending
  end
end
