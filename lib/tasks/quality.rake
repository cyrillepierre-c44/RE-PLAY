namespace :quality do
  desc "Reconstruit l'historique des contrôles qualité (QualityCheck) à partir du journal des actions"
  # Avant le 16/11/2026 les décisions du CQ n'existaient que dans le journal
  # (« … a passé le jouet J12 en statut: review »). Cette tâche en tire un
  # QualityCheck par décision pour que le tableau de bord ait un historique.
  # Sans danger à relancer : un jouet qui a déjà des contrôles est ignoré.
  # Limites de la reconstruction : causes déduites des anciens critères cochés,
  # pas de commentaire CQ par tour (l'ancien commentaire va sur le dernier refus),
  # pas de date de retraitement (l'ancien parcours ne la connaissait pas).
  # Essai à blanc : DRY_RUN=1 bin/rails quality:backfill
  task backfill: :environment do
    dry = ENV["DRY_RUN"].present?
    old_causes = { "français" => "langue", "CE" => "ce", "sécurité" => "securite", "propreté" => "nettoyage",
                   "complet" => "completude", "jouable" => "panne", "catégorie" => "categorie" }
    decisions = { "review" => "refused", "market" => "accepted" }
    created = Hash.new(0)

    toy_ids = Action.where(actionable_type: "Toy").where("content LIKE ?", "%en statut: %").distinct.pluck(:actionable_id)
    Toy.where(id: toy_ids).where.missing(:quality_checks).find_each do |toy|
      actions = Action.where(actionable: toy).order(:created_at, :id).to_a
      checks = []
      actions.each do |action|
        status = action.content[/en statut: (\w+)/, 1]
        decision = decisions[status] or next
        next if decision == "accepted" && checks.last&.decision == "accepted" # simple correction d'un jouet en vente

        causes = []
        if decision == "refused"
          causes = actions.select { |a| a.content.start_with?("[NC:") && (a.created_at - action.created_at).abs < 10 }
                          .filter_map { |a| old_causes.find { |key, _| a.content.start_with?("[NC:#{key}") }&.last }.uniq
        end
        checks.last&.resolved_at ||= action.created_at
        checks << QualityCheck.new(toy: toy, round: [checks.size + 1, 2].min, decision: decision, causes: causes,
                                   operator_id: toy.operator_id, checker_id: action.user_id,
                                   created_at: action.created_at, updated_at: action.created_at)
      end
      next if checks.empty?

      last_refusal = checks.reverse.find(&:refused?)
      last_refusal.cq_comment = toy.admin_comment.presence unless toy.pricing_blocked? || last_refusal.nil?
      checks.each do |check|
        created[check.decision] += 1
        check.save!(validate: false) unless dry
      end
    end
    puts "#{'[essai à blanc] ' if dry}Contrôles reconstruits : #{created['accepted']} validés, #{created['refused']} refusés."
  end
end
