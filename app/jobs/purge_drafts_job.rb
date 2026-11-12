# Supprime les brouillons (jouets et caisses) abandonnés depuis plus de
# Draftable::DRAFT_TTL — planifié dans config/recurring.yml.
class PurgeDraftsJob < ApplicationJob
  queue_as :default

  def perform
    toys = Toy.purge_stale_drafts!
    boxes = Box.purge_stale_drafts!
    Rails.logger.info("PurgeDraftsJob : #{toys} jouet(s) et #{boxes} caisse(s) en brouillon supprimés")
  end
end
