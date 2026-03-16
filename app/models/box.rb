class Box < ApplicationRecord
  belongs_to :category
  has_many :actions, as: :actionable
  has_many :toys, dependent: :destroy

  enum :status, { pending: "pending", empty: "empty", suppr: "suppr" }
  after_initialize :set_default_status, if: :new_record?

  validates :status, presence: true
  scope :active,   -> { where.not(status: :suppr) }
  scope :deleted,  -> { where(status: :suppr) }

  private

  def set_default_status
    self.status ||= :pending
  end
end
