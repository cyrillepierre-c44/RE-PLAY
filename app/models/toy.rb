class Toy < ApplicationRecord
  belongs_to :box
  belongs_to :category
  has_many :actions, as: :actionable
end
