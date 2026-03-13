class Toy < ApplicationRecord
  belongs_to :box
  belongs_to :category
  has_many :actions, as: :actionable
  has_many :users, through: :actions
  has_one_attached :photo, dependent: :destroy
  enum :status, { pending: "pending", market: "market", suppr: "suppr", review: "review" }
  after_initialize :set_default_status, if: :new_record?

  validates :status, presence: true
  scope :waiting, -> { where(status: %i[pending review]) }
  scope :validated, -> { where(status: %i[market suppr]) }
  private

  def set_default_status
    self.status ||= :pending
  end
end
