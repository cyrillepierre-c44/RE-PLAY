class Box < ApplicationRecord
  belongs_to :category
  belongs_to :user
  has_many :actions, as: :actionable
end
