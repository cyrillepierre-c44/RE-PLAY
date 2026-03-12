class Toy < ApplicationRecord
  after_initialize :set_default_location, if: :new_record?
  belongs_to :box
  belongs_to :category
  has_many :actions, as: :actionable
  has_many :users, through: :actions
  has_one_attached :photo, dependent: :destroy
  validates :location, presence: true

  private

  def set_default_location
    self.location ||= "En attente de validation"
  end
end
