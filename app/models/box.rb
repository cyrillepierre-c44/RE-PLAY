class Box < ApplicationRecord
  belongs_to :category
  has_many :actions, as: :actionable
  has_many :toys, dependent: :destroy

  enum :status, { pending: "pending", empty: "empty" }
  after_initialize :set_default_status, if: :new_record?

  validates :status, presence: true

  private

  def set_default_status
    self.status ||= :pending
  end
end
