class PriceiaJob < ApplicationJob
  queue_as :default

  def perform(toy_id, clean:, complete:, playable:)
    toy = Toy.find(toy_id)

    chat = RubyLLM.chat(model: "gpt-4o")
    response = chat.ask(system_prompt(clean, complete, playable), with: { image: toy.photo.url })
    toy.update(price: response.content.to_i)
  end

  private

  def system_prompt(clean, complete, playable)
    "Tu es un expert en vente de jouet d'occasion reconditionnés par des ateliers francais.
    Je travaille pour une entreprise Française, dans la zone euros, qui reconditionne et vend des jouets d'occasion
    et je souhaite savoir à quel prix je peux les vendre en tenant compte des prix pratiqués par la concurrence
    pour le même jouet ou des jouets similaires qui lui ressemble.
    Peux-tu m'aider à trouver le prix de vente de ce jouet d'occasion en te basant aussi sur
    l'état decrit ci-apres: Le jouet est
    #{clean ? 'propre' : 'sale'},
    #{complete ? 'complet' : 'incomplet'} et
    #{playable ? 'fonctionnel' : 'non fonctionnel'}.
    Merci de me faire une réponse en chiffres uniquement et sans lettres ni unité d'argent avec la valeur
    moyenne seulement. Par exemple : 10"
  end
end
