class PriceiaJob < ApplicationJob
  queue_as :default

  def perform(toy_id, french:, ce_mark:, safe:, clean:, complete:, playable:)
    toy = Toy.find(toy_id)

    chat = RubyLLM.chat(model: "gpt-4o")
    response = chat.ask(system_prompt(french, ce_mark, safe, clean, complete, playable, toy.operator_note), with: { image: toy.photo.url })
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
    - Jeu en français : #{french ? 'oui' : 'non'} #{french ? '' : '(malus : moins attractif pour le marché français)'}
    - Marquage CE ou marque connue : #{ce_mark ? 'oui' : 'non'} #{ce_mark ? '' : '(malus : moins rassurant pour les parents)'}
    - Sécurité vérifiée : #{safe ? 'oui' : 'non'} #{safe ? '' : '(malus significatif : risque perçu élevé)'}
    - Propreté : #{clean ? 'propre' : 'sale'} #{clean ? '' : '(malus : doit être nettoyé)'}
    - Complétude : #{complete ? 'complet' : 'incomplet'}
    - Jouabilité : #{playable ? 'jouable' : 'non jouable'} #{playable ? '' : '(malus fort : jouet inutilisable)'}#{note_part}

    Réponds uniquement avec un nombre entier en euros, sans texte ni symbole. Exemple : 8"
  end
end
