class Action < ApplicationRecord
  belongs_to :user
  belongs_to :actionable, polymorphic: true
end
