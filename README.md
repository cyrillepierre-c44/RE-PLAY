# RE-PLAY

Application de gestion d'atelier de revalorisation de jouets (association Enjoué) :
réception des caisses, tri et fiche par jouet (photo, critères qualité, prix suggéré
par IA), contrôle qualité admin, mise en rayon et suivi d'activité (dashboard, export CSV).

Stack : Rails 8.1 · PostgreSQL · Hotwire (Turbo/Stimulus) · Bootstrap 5.3 ·
Solid Queue/Cache/Cable · Devise + Pundit · Cloudinary (photos) · Mammouth.ai (prix IA).

## Setup

```bash
bundle install
bin/rails db:create db:migrate db:seed
bin/rails s
```

Variables d'environnement (fichier `.env`, non committé) :

| Variable | Rôle |
|---|---|
| `CLOUDINARY_URL` | Stockage des photos (production ; en dev le disque local est utilisé) |
| `MAMMOUTH_API_KEY` | API LLM pour la suggestion de prix (`PriceiaJob`) |
| `GMAIL_USERNAME` / `GMAIL_PASSWORD` | SMTP production (en dev, letter_opener ouvre les mails dans le navigateur) |
| `SENTRY_DSN` | Monitoring d'erreurs (production uniquement, optionnel ailleurs) |

Les comptes utilisateurs sont créés par un admin depuis l'app (pas d'inscription publique).

## Tests & qualité

```bash
bin/rails test        # suite Minitest (modèles, policies Pundit, controllers)
bin/rubocop           # lint (0 offense attendu)
bin/brakeman          # analyse statique sécurité
bin/bundler-audit     # CVE des gems
```

La CI GitHub Actions (`.github/workflows/ci.yml`) rejoue tout ça sur chaque push/PR.

## Déploiement

Heroku, app `re-play` : `git push heroku master`. La release phase du `Procfile`
joue les migrations automatiquement. Les jobs Solid Queue tournent dans Puma
(config var `SOLID_QUEUE_IN_PUMA`). Healthcheck : `GET /up` (surveillé par UptimeRobot).
