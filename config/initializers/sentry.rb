# Monitoring des erreurs en production (compte Sentry de Cyrille).
# Sans SENTRY_DSN (dev, test, CI), l'initialisation est sautée : aucun envoi.
if ENV["SENTRY_DSN"].present?
  Sentry.init do |config|
    config.dsn = ENV["SENTRY_DSN"]
    config.breadcrumbs_logger = %i[active_support_logger http_logger]

    # RGPD : ne pas transmettre d'informations personnelles (emails, IP…)
    config.send_default_pii = false

    # Traces de performance : 10 % des requêtes suffisent pour ce volume.
    config.traces_sample_rate = 0.1

    # Les URL inconnues (bots, scans) génèrent du bruit sans valeur.
    config.excluded_exceptions += ["ActionController::RoutingError"]
  end
end
