class Toy < ApplicationRecord
  belongs_to :box
  belongs_to :category
  has_many :actions, as: :actionable
  has_many :users, through: :actions
  has_one_attached :photo, dependent: :destroy
<<<<<<< HEAD
  enum :status, { pending: "pending", market: "market", suppr: "suppr", review: "review" }
  after_initialize :set_default_status, if: :new_record?

  validates :status, presence: true
  scope :waiting, -> { where(status: %i[pending review]) }
  scope :validated, -> { where(status: %i[market suppr]) }
  private

  def set_default_status
    self.status ||= :pending
  end
=======
  validates :location, presence: true
  scope :waiting, -> { where(location: "En attente de validation") }
  scope :validated, -> { where.not(location: "En attente de validation").where.not(location: [nil, ""]) }

  private
>>>>>>> master
end
