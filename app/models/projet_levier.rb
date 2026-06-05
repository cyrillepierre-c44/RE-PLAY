class ProjetLevier < ApplicationRecord
  validates :module_code, presence: true, inclusion: { in: %w[A B C] }
  validates :numero, presence: true, inclusion: { in: 1..5 }
  validates :progression, numericality: { in: 0..100 }
  validates :module_code, uniqueness: { scope: :numero }
end
