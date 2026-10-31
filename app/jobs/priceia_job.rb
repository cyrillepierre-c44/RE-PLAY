class PriceiaJob < ApplicationJob
  queue_as :default

  MODEL = "claude-haiku-5-5".freeze

  # Le modèle a refusé de répondre (stop_reason « refusal ») : traité comme une image refusée.
  class PricingRefused < StandardError; end

  # On exécute les jobs de pricing un par un pour rester sous les limites
  # de débit de l'API Claude
  limits_concurrency to: 1, key: "priceia"

  # et on retente avec un délai croissant si l'API rate-limite quand même
  retry_on Anthropic::Errors::RateLimitError, wait: :polynomially_longer, attempts: 8

  # Les pannes passagères de l'API (500, 529 « overloaded », coupures réseau, délais dépassés) sont
  # déjà retentées 2 fois par la gem anthropic, mais à quelques secondes d'écart : on laisse au
  # fournisseur le temps de revenir avant de lever une vraie erreur pour Sentry.
  # (APITimeoutError hérite d'APIConnectionError.)
  retry_on Anthropic::Errors::InternalServerError, Anthropic::Errors::APIConnectionError,
           wait: :polynomially_longer, attempts: 5

  # Une image refusée par l'API (400 : image illisible ou introuvable, contenu refusé) le sera à
  # chaque essai : on ne réessaie pas, on le dit à l'opérateur sur la fiche du jouet et on prévient
  # Sentry en simple avertissement — ce n'est pas une panne, c'est un jouet à tarifer à la main.
  # Même traitement quand le modèle refuse de répondre (stop_reason « refusal », voir #perform).
  discard_on Anthropic::Errors::BadRequestError, PricingRefused do |job, error|
    toy_id = job.arguments.first
    Toy.find_by(id: toy_id)&.mark_pricing_blocked!
    Rails.logger.warn("PriceiaJob : estimation refusée pour le jouet #{toy_id} — #{error.message}")
    if defined?(Sentry) && Sentry.initialized?
      Sentry.capture_message("PriceiaJob : image refusée par le fournisseur (jouet #{toy_id}) — #{error.message.to_s.first(300)}",
                             level: :warning)
    end
  end

  # Client de l'API Claude (clé lue dans ENV["ANTHROPIC_API_KEY"]) ; redéfini dans les tests.
  def self.client
    @client ||= Anthropic::Client.new
  end

  def perform(toy_id, french:, ce_mark:, safe:, clean:, complete:, playable:)
    toy = Toy.find(toy_id)

    message = self.class.client.messages.create(
      model: MODEL,
      # la réflexion du modèle compte dans max_tokens : on laisse de la marge pour un prix d'un mot
      max_tokens: 2048,
      # effort bas : tâche courte, on limite la réflexion (et donc le coût)
      output_config: { effort: :low },
      messages: [{
        role: "user",
        content: [
          { type: "image", source: { type: "url", url: toy.photo.url } },
          { type: "text", text: system_prompt(french, ce_mark, safe, clean, complete, playable, toy.operator_note) }
        ]
      }]
    )
    raise PricingRefused, "refus du modèle (#{message.stop_details&.category || 'sans catégorie'})" if message.stop_reason == :refusal

    # la réponse peut commencer par des blocs de réflexion : on ne lit que le texte
    answer = message.content.select { |block| block.type == :text }.map(&:text).join
    price = answer[/\d+/]
    if price
      toy.update(price: price.to_i)
    else
      Rails.logger.warn("PriceiaJob : réponse sans prix pour le jouet #{toy_id} — #{answer.first(200).inspect}")
    end
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
