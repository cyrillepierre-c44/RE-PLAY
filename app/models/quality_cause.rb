# Catalogue des causes de non-conformité, unifié avec Enjoué le 16/11/2026
# (tableur « Jouets à revaloriser » du client + critères historiques de l'appli
# + consignes du TRI). Les clés sont stockées en base : ne pas les renommer.
#
# - CQ : problèmes détectés au contrôle qualité (refus → revalorisation).
# - DISCARD : causes du jet à l'entrée de la VALO. `tri: true` = le TRI aurait dû
#   écarter le jouet (affiche « Objets non acceptés au TRI ») : compte contre le
#   Bon du 1er coup du TRI. `tri: false` = découvert à la VALO, le TRI ne le
#   vérifie pas (complétude, propreté, langue…).
class QualityCause
  Cause = Struct.new(:key, :label, :icon, :help, :tri, keyword_init: true)

  CQ = [
    { key: "completude",  label: "Complétude",        icon: "fa-list-check",
      help: "Il manque des pièces, la règle ou un élément du jeu." },
    { key: "abime",       label: "Abîmé / déchiré",   icon: "fa-heart-crack",          help: "Jouet ou boîte abîmé, déchiré, décollé." },
    { key: "nettoyage",   label: "Nettoyage",         icon: "fa-soap",                 help: "Le jouet ou la boîte est encore sale." },
    { key: "panne",       label: "Ne fonctionne pas", icon: "fa-gamepad",
      help: "Le jouet ne marche pas ou n'est pas jouable." },
    { key: "incoherence", label: "Incohérence",       icon: "fa-shuffle",
      help: "Le lot mélange des éléments qui ne vont pas ensemble." },
    { key: "photo",       label: "Photo",             icon: "fa-camera",
      help: "Photo absente, floue ou qui ne montre pas le jouet." },
    { key: "prix",        label: "Prix",              icon: "fa-euro-sign", help: "Le prix ne correspond pas au jouet." },
    { key: "securite",    label: "Sécurité",          icon: "fa-triangle-exclamation",
      help: "Danger pour l'enfant : coupant, petites pièces, rouille." },
    { key: "categorie",   label: "Catégorie",         icon: "fa-tag",
      help: "Le jouet n'est pas dans la bonne catégorie." },
    { key: "ce",          label: "CE / marque",       icon: "fa-award",                help: "Pas de marquage CE ni de marque connue." },
    { key: "langue",      label: "Pas en français",   icon: "fa-flag",                 help: "Le jeu ou le livre n'est pas en français." }
  ].map { |attrs| Cause.new(**attrs) }.freeze

  DISCARD = [
    { key: "sans_ce",        tri: true,  label: "Sans CE",           icon: "fa-award", help: "Pas de marquage CE." },
    { key: "publicitaire",   tri: true,  label: "Publicitaire",      icon: "fa-bullhorn",
      help: "Jouet publicitaire ou promotionnel (McDonald's, Quick…)." },
    { key: "trop_abime",     tri: true,  label: "Trop abîmé",        icon: "fa-heart-crack",
      help: "Cassé, recollé, mordu ; peluche déchirée ; livre abîmé." },
    { key: "dangereux",      tri: true,  label: "Dangereux",         icon: "fa-triangle-exclamation",
      help: "Plastique coupant, peinture écaillée, rouille." },
    { key: "personnalise",   tri: true,  label: "Personnalisé",      icon: "fa-signature",
      help: "Prénom gravé, étiquette cousue, ou jouet fait maison." },
    { key: "electronique",   tri: true,  label: "Électronique HS",   icon: "fa-battery-empty",
      help: "Ne s'allume plus, ou piles qui ont coulé." },
    { key: "puzzle",         tri: true,  label: "Puzzle refusé",     icon: "fa-puzzle-piece",
      help: "Plus de 60 pièces, ou puzzle sans boîte." },
    { key: "livre",          tri: true,  label: "Livre refusé",      icon: "fa-book",
      help: "Pas pour l'âge visé, ou contenu inapproprié." },
    { key: "hors_perimetre", tri: true,  label: "Pas un jouet",      icon: "fa-ban",
      help: "Sac, décoration, puériculture, trop volumineux, CD ou DVD." },
    { key: "incomplet",      tri: false, label: "Incomplet",         icon: "fa-list-check",
      help: "Il manque trop de pièces pour le vendre." },
    { key: "sale",           tri: false, label: "Trop sale",         icon: "fa-soap", help: "Impossible à nettoyer." },
    { key: "pas_francais",   tri: false, label: "Pas en français",   icon: "fa-flag",
      help: "Le jeu ou le livre n'est pas en français." },
    { key: "en_panne",       tri: false, label: "Ne fonctionne pas", icon: "fa-gamepad",
      help: "Jouet non électronique qui ne marche pas." }
  ].map { |attrs| Cause.new(**attrs) }.freeze

  CQ_KEYS = CQ.map(&:key).freeze
  DISCARD_KEYS = DISCARD.map(&:key).freeze
  TRI_KEYS = DISCARD.select(&:tri).map(&:key).freeze

  def self.cq(key) = CQ.find { |c| c.key == key }
  def self.discard(key) = DISCARD.find { |c| c.key == key }
  def self.cq_labels(keys) = Array(keys).filter_map { |k| cq(k)&.label }
  def self.discard_labels(keys) = Array(keys).filter_map { |k| discard(k)&.label }
end
