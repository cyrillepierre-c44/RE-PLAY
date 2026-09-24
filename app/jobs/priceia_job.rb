class PriceiaJob < ApplicationJob
  queue_as :default

  # On exécute les jobs de pricing un par un pour rester sous les limites
  # de débit de l'API Mammouth
  limits_concurrency to: 1, key: "priceia"

  # et on retente avec un délai croissant si l'API rate-limite quand même
  retry_on RubyLLM::RateLimitError, wait: :polynomially_longer, attempts: 8

  # Une image refusée par le filtre de sécurité du fournisseur (400 « content safety ») le sera à
  # chaque essai : on ne réessaie pas, on le dit à l'opérateur sur la fiche du jouet et on prévient
  # Sentry en simple avertissement — ce n'est pas une panne, c'est un jouet à tarifer à la main.
  discard_on RubyLLM::BadRequestError do |job, error|
    toy_id = job.arguments.first
    Toy.find_by(id: toy_id)&.mark_pricing_blocked!
    Rails.logger.warn("PriceiaJob : estimation refusée pour le jouet #{toy_id} — #{error.message}")
    Sentry.capture_message("PriceiaJob : image refusée par le fournisseur (jouet #{toy_id}) — #{error.message.to_s.first(300)}", level: :warning) if defined?(Sentry) && Sentry.initialized?
  end

  def perform(toy_id, french:, ce_mark:, safe:, clean:, complete:, playable:)
    toy = Toy.find(toy_id)

    chat = RubyLLM.chat(model: "gpt-4.1-mini")
    response = chat.ask(system_prompt(french, ce_mark, safe, clean, complete, playable, toy.operator_note),
                        with: { image: toy.photo.url })
    toy.update(price: response.content.to_i)
  end

  private

  def system_prompt(french, ce_mark, safe, clean, complete, playable, operator_note = nil)
    note_part = operator_note.present? ? "\n    Note de l'opérateur (à prendre en compte pour ajuster le prix) : \"#{operator_note}\"." : ""

    "Tu es un expert en reconditionnement et revente de jouets d'occasion pour des ateliers français solidaires.
    On te demande d'estimer un prix de revente pour un jouet d'occasion reconditionné.

    Méthode de calcul à suivre dans cet ordre de priorité :
    1. Si le prix neuf est disponible pour ce jouet, divise-le par 2 pour obtenir le prix de base.
    2. Sinon, aligne-toi sur le prix du marché de l'occasion (leboncoin, vinted, ebay fr) pour un jouet similaire en bon état.
    3. Ajuste ensuite ce prix de base selon les critères d'état et la note de l'opérateur ci-dessous.

    Critères d'état du jouet :
    - Jeu en français : #{french ? 'oui' : 'non'} #{'(malus : moins attractif pour le marché français)' unless french}
    - Marquage CE ou marque connue : #{ce_mark ? 'oui' : 'non'} #{'(malus : moins rassurant pour les parents)' unless ce_mark}
    - Sécurité vérifiée : #{safe ? 'oui' : 'non'} #{'(malus significatif : risque perçu élevé)' unless safe}
    - Propreté : #{clean ? 'propre' : 'sale'} #{'(malus : doit être nettoyé)' unless clean}
    - Complétude : #{complete ? 'complet' : 'incomplet'}
    - Jouabilité : #{playable ? 'jouable' : 'non jouable'} #{'(malus fort : jouet inutilisable)' unless playable}#{note_part}

    Réponds uniquement avec un nombre entier en euros, sans texte ni symbole. Exemple : 8"
  end
end
