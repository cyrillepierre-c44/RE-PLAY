# Monitoring des erreurs en production (compte Sentry de Cyrille).
# Sans SENTRY_DSN (dev, test, CI), l'initialisation est sautée : aucun envoi.
#
# Les processus jetables — `rails runner` (scripts de vérification lancés sur
# un dyno `heroku run`, qui reçoit les mêmes variables que la production) et
# `rails console` — ne sont pas de la production : une exception qui y remonte
# est un script qui a échoué, pas un visiteur touché. Rails ne charge que la
# classe de la commande invoquée : sa présence dit dans quel processus on est.
disposable_process = defined?(Rails::Command::RunnerCommand) || defined?(Rails::Command::ConsoleCommand)

if ENV["SENTRY_DSN"].present? && !disposable_process
  Sentry.init do |config|
    config.dsn = ENV.fetch("SENTRY_DSN")
    config.breadcrumbs_logger = %i[active_support_logger http_logger]

    # RGPD : ne pas transmettre d'informations personnelles (emails, IP…)
    config.send_default_pii = false

    # Traces de performance : 10 % des requêtes suffisent pour ce volume.
    config.traces_sample_rate = 0.1

    # Les URL inconnues (bots, scans) génèrent du bruit sans valeur.
    config.excluded_exceptions += ["ActionController::RoutingError"]
  end
end
