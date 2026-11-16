# Objectifs qualité réglables par les admins (ligne unique).
class QualitySetting < ApplicationRecord
  validates :target_valo, :target_tri, numericality: { only_integer: true, in: 0..100 }
  validates :red_after_days, numericality: { only_integer: true, in: 1..30 }
  # En dessous de ce nombre de jouets contrôlés, pas de pourcentage affiché.
  validates :min_sample, numericality: { only_integer: true, in: 1..500 }

  def self.current
    first || create!
  end
end
