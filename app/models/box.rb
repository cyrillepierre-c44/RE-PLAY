class Box < ApplicationRecord
  belongs_to :category
  has_many :actions, as: :actionable
end
