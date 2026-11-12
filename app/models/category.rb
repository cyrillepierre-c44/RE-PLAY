class Category < ApplicationRecord
  has_many :boxes, dependent: :destroy

  # `mixed` : catégorie de caisse qui mélange plusieurs catégories de jouets
  # (« Grosses pièces » : les jouets encombrants partagent un même roll).
  # Elle se choisit pour une caisse, jamais pour un jouet.
  scope :for_toys, -> { where(mixed: false) }
end
