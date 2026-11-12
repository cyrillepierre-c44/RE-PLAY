# Brouillon : le numéro (id) d'un jouet ou d'une caisse est réservé dès le début
# de la création, pour que plusieurs personnes puissent étiqueter en parallèle.
# Tant que le formulaire n'a pas été enregistré une première fois, la fiche reste
# en statut `draft` : elle ne compte nulle part, seul son créateur (et l'admin) la
# voit, « à terminer ». La flèche retour du formulaire la supprime (fausse manip),
# et les brouillons oubliés sont purgés après DRAFT_TTL (PurgeDraftsJob).
module Draftable
  extend ActiveSupport::Concern

  DRAFT_TTL = 7.days

  included do
    scope :stale_drafts, -> { draft.where(created_at: ...DRAFT_TTL.ago) }
  end

  class_methods do
    def purge_stale_drafts!
      stale_drafts.to_a.each(&:discard_draft!).size
    end
  end

  # Suppression définitive (fiche + historique) : un brouillon n'a jamais existé
  # pour l'atelier. Refusée pour tout autre statut, qui passe par la corbeille.
  def discard_draft!
    raise ArgumentError, "#{self.class.name} ##{id} n'est pas un brouillon" unless draft?

    transaction do
      Action.where(actionable: self).delete_all
      destroy!
    end
  end
end
