class Toy < ApplicationRecord
  after_initialize :set_default_location, if: :new_record?
  belongs_to :box
  belongs_to :category
  has_many :actions, as: :actionable
  has_many :users, through: :actions
  has_one_attached :photo, dependent: :destroy
  validates :location, presence: true
  scope :waiting, -> { where(location: "En attente de validation") }
  scope :validated, -> { where.not(location: "En attente de validation").where.not(location: [nil, ""]) }
  private

  def set_default_location
    self.location ||= "En attente de validation"
  end
end
