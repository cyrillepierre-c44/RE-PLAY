class Toy < ApplicationRecord
  belongs_to :box
  belongs_to :category
  has_many :actions, as: :actionable
  has_many :users, through: :actions
  has_many :photos, as: :imageable
end
