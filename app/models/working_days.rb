# Délais en jours ouvrés, du lundi au vendredi (décision Enjoué du 16/11/2026 :
# le week-end ne compte pas ; les jours fériés ne sont pas gérés).
module WorkingDays
  ZONE = "Europe/Paris".freeze

  # Nombre de jours ouvrés écoulés depuis `from` : 0 le jour même, 1 le jour
  # ouvré suivant… Un refus du vendredi vaut 1 le lundi.
  def self.elapsed(from, to = Time.current)
    start_date = from.in_time_zone(ZONE).to_date
    end_date = to.in_time_zone(ZONE).to_date
    return 0 if end_date <= start_date

    ((start_date + 1)..end_date).count { |day| !day.saturday? && !day.sunday? }
  end
end
