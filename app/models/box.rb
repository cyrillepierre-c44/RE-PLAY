class Box < ApplicationRecord
  belongs_to :category
  has_many :actions, as: :actionable
  has_many :toys, dependent: :destroy
end
