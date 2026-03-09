class Category < ApplicationRecord
  has_many :boxes, dependent: :destroy
end
