# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Development
bin/dev                        # Start development server (Rails + assets)
bin/rails server               # Rails server only
bin/rails console              # Rails console

# Database
bin/rails db:migrate           # Run migrations
bin/rails db:seed              # Seed database
bin/rails db:test:prepare      # Prepare test database

# Testing
bin/rails test                 # Run all unit/integration tests
bin/rails test:system          # Run system tests
bin/rails test test/models/toy_test.rb  # Run a single test file

# Linting & Security
bin/rubocop                    # Lint Ruby code
bin/brakeman --no-pager        # Security static analysis
bin/bundler-audit              # Audit gem vulnerabilities
bin/importmap audit            # Audit JS dependencies
```

## Architecture

Rails 8.1.2 app (Ruby 3.3.5) bootstrapped from the Le Wagon template. PostgreSQL database. Frontend uses Bootstrap 5.3 + Hotwire (Turbo + Stimulus) with importmaps (no Node/webpack).

### Domain Model

The app manages donated/refurbished toy inventory for a French resale operation:

- **Category** — top-level grouping (e.g. puzzle, jeu de société)
- **Box** — a physical donation box, belongs to a Category, has weight and electronic flag
- **Toy** — individual toy, belongs to a Box and Category. Has condition fields (`clean`, `complete`, `playable`), `location` (defaults to "En attente de validation"), `price` (AI-suggested), `barcode`, and an attached `photo`
- **Action** — polymorphic audit log; records every user action on a Box or Toy with a `content` string. Also used to determine ownership for authorization.
- **User** — Devise authentication with an `admin` boolean flag
- **ProjetLevier** — tracks the selection and progression of each levier in the Projet devis. Fields: `module_code` (A/B/C), `numero` (1–5), `actif` (boolean, default true), `progression` (integer 0–100). Unique index on [module_code, numero]. Auto-created on first visit to `/projet`.

### Authorization (Pundit)

All controllers require authentication (`authenticate_user!`). Pundit is enforced globally via `verify_authorized`/`verify_policy_scoped` after actions, with an exception for Devise and pages controllers.

Key authorization rules:
- **Edit/update** on Box or Toy: only the user who originally acted on it (`record.actions.where(user: user).any?`)
- **Destroy Toy / Verify Toy**: admin only (`user.admin?`)
- **Destroy Box**: the creator (via actions)
- **Projet / ProjetLeviers**: admin only (`user.admin?`) — via `PagePolicy#projet?`

### Toy Lifecycle

1. Toy is created with `location: "En attente de validation"` (scope: `Toy.waiting`)
2. After create/update, a `PriceiaJob` calls the Claude API (Haiku 5.5) to suggest a price based on a French prompt + toy photo
3. Admin verifies the toy via `GET /toys/:id/verify` → `PATCH /toys/:id/confirm_verify`, which updates location and moves it to `Toy.validated` scope
4. Toys index supports `?filter=validated` to toggle between waiting and validated views

### AI Pricing

When a toy is created or updated, `PriceiaJob` calls the Claude API (official `anthropic` gem, `PriceiaJob::MODEL` = `claude-haiku-5-5`, `effort: :low`), passing the toy photo (Cloudinary URL as an `image` block with a `url` source) and a French-language prompt describing the toy's condition. The text of the response (a number) is saved as `toy.price` — the response may start with `thinking` blocks, so only `text` blocks are read. API key: `ENV["ANTHROPIC_API_KEY"]` (Anthropic Console key `re-play`, pay-as-you-go — a Claude Code subscription cannot be used; set in `.env` and on Heroku). **The key expires on 30/11/2026**: after that every pricing call fails with `Anthropic::Errors::AuthenticationError` (401, raised to Sentry) — create a new key and update `.env` + `heroku config:set` before then. Migrated from Mammouth/ruby_llm (gpt-4.1-mini) on 31/10/2026; measured 31/10/2026 on a real photo: ~2 480 input + ~200–290 output tokens (thinking included) ≈ 0.00035–0.0004 $ per toy, ~2–3 s, vs 0.0006 $ before. Anthropic fetches Cloudinary URLs fine (verified); some hosts (e.g. Wikimedia) refuse its downloader → 400 « Unable to download the file ». In dev, Disk-service photos have localhost URLs the API cannot reach, so dev pricing fails unless the photo is on Cloudinary. Claude Haiku 5.5 rejects `temperature`/`top_p`/`top_k` and assistant prefill — don't add them.

400 errors (image unreadable/refused) and `stop_reason: :refusal` → toy marked « prix à saisir » (`mark_pricing_blocked!`), Sentry warning only, no retry.

**Logs** : chaque calcul écrit une ligne `PriceiaJob : J5491 → 10 € (sale) — 2901 + 150 jetons, ≈0.00037 $` (critères en malus, ou « parfait état » ; coût calculé avec `INPUT_/OUTPUT_PRICE_PER_MTOK`, à mettre à jour si le modèle change). Lire avec `heroku logs -a re-play -n 300 | grep "PriceiaJob :"`.

**Prompt** : chaque critère défavorable porte un malus explicite (« incomplet » ajouté le 31/10/2026). **Variabilité** : sans température réglable, une même photo varie d'environ ±2 € (J5491 : 5/12 € puis 6/10 € en incomplet/complet). À revoir à l'usage début novembre 2026 ; piste en attente : faire choisir le prix dans une grille de prix ronds (2, 3, 5, 8, 10, 12, 15, 20 €…).

**Pannes passagères de l'API (500, 529 « overloaded », coupures réseau, timeouts)** : `PriceiaJob` les retente 5 fois avec un délai croissant (~7 min au total), en plus des 2 essais rapides de la gem. Sentry ne remonte `Anthropic::Errors::InternalServerError` / `APIConnectionError` que si la panne dure plus longtemps ; le jouet reste alors sans prix, à relancer via le bandeau violet. Un seul incident connu (30/09/2026, encore chez Mammouth). Si Sentry le remonte à nouveau, plan prévu (non fait, jugé disproportionné après un seul cas) :
1. Retries épuisés → le jouet passe « en attente de reprise IA » (colonne dédiée, par ex. `pricing_waiting_since`) au lieu d'échouer ; avertissement Sentry seulement.
2. Job récurrent (`config/recurring.yml`, toutes les 10 min) : s'il y a des jouets en attente, il fait **un** vrai mini-appel `messages.create` sur `PriceiaJob::MODEL` (pas un ping `/v1/models` : « upstream connect error » vient d'Envoy, donc la passerelle peut répondre alors que le chat est en panne) ; si ça marche, il relance `PriceiaJob` pour eux ; au-delà de 24 h de panne, erreur Sentry.
3. Fiche jouet : icône « en attente » au lieu du robot qui tourne.
4. En option, un disjoncteur (clé Solid Cache) seulement si beaucoup de jouets sont saisis pendant une panne.
Modèle de secours : si les pannes se répètent, en cas d'erreur passagère, un seul essai sur un autre modèle Claude (par ex. `claude-sonnet-5-5`, plus cher) ; chaque nouveau job réessaie Haiku d'abord. Les prix diffèrent d'un modèle à l'autre (le signaler sur la fiche).

### Routes

```
root → pages#home
/boxes               → BoxesController (index, show, new, create, edit, update, destroy)
/boxes/:id/toys      → ToysController  (new, create — nested)
/toys                → ToysController  (index, show, edit, update, destroy)
/toys/:id/verify         GET   → verify form (admin only)
/toys/:id/confirm_verify PATCH → save verification result (admin only)
/about_us, /onboarding, /enjoue → PagesController (Pundit skipped)
/projet                  GET   → pages#projet (admin only)
/projet_leviers/:id      PATCH → projet_leviers#update (admin only)
```

### Page Projet (devis RE-PLAY V2)

Admin-only page at `/projet` displaying a 7-page consulting quote (devis N° 2026-RPV2-01) with interactive tracking features.

**Structure :**
- `app/views/pages/projet.html.erb` — 7 devis pages (`.devis-page`) inside `.projet-devis-wrapper`
- `app/assets/stylesheets/pages/_projet.scss` — all devis styles, scoped under `.projet-devis-wrapper`
- `app/views/pages/_levier_track.html.erb` — partial rendered in each levier for toggle + progress bar

**Print / paper mode :**
- Toolbar (sticky, `#1a2332`) with 3 buttons: mode papier, imprimer, partager
- `body.paper-mode` class for print-preview look (white backgrounds)
- `@media print`: hides toolbar/navbar, forces A4 layout (`break-after: page`), hides `.levier-track` and `.levier--off`
- Mobile scaling via `transform: scale()` on `.devis-page` elements (IIFE JS at bottom of view)

**Levier tracking (Stimulus) :**
- 15 leviers across pages 3/4/5 (Modules A/B/C, leviers 1–5 each)
- Each levier div: `data-controller="levier-tracker"` with values `id`, `actif`, `module`, `numero`
- Toggle (actif/exclu) + barre de progression (0–100%) persistés via `PATCH /projet_leviers/:id`
- Stimulus controller: `app/javascript/controllers/levier_tracker_controller.js`
  - Dispatches `levier:toggled` on `window` after each toggle
- Leviers exclus (`levier--off`): opacity 0.4 à l'écran, masqués à l'impression

**Recap tables dynamiques (Stimulus) :**
- 4 tableaux : Module A (page 3), Module B (page 4), Module C (page 5), récapitulatif global (page 6)
- Chaque tableau a `data-controller="recap"` ; les 3 tableaux modules ont aussi `data-recap-module-value="X"`
- Lignes de leviers : `data-recap-target="row"` + `data-levier-num`, `data-hours`, `data-budget`
- Totaux : `data-recap-target="totalHours/totalBudget"` (modules) et `grandHours/grandBudget` (global)
- Stimulus controller: `app/javascript/controllers/recap_controller.js`
  - Écoute `levier:toggled` sur `window`, masque/affiche les lignes et recalcule les totaux
  - Totaux initiaux calculés côté serveur (Ruby) dans la vue selon l'état `actif` en base
- Lignes TOTAL MODULE / TOTAL PROJET V2 : fond or `#c9a84c`, texte marine `#1a1a2e`

### File Storage

Active Storage + Cloudinary for toy photos. Requires `CLOUDINARY_URL` in the environment.

- Stored/served size: `config/storage.yml` applies `c_limit,w_1600,h_1600,q_auto` (~88 Ko/photo) — used on the toy page and the verify screen.
- **List cards** (`toys/index`, `boxes/show`) must use `toy_thumb_tag(toy)` (`ApplicationHelper`), never `image_tag toy.photo`: Cloudinary thumbnail 720×400 `c_fill,g_center,q_auto,f_auto` (~24 Ko WebP) + `loading="lazy"`. Falls back to the original photo outside Cloudinary (dev Disk, tests). Reason: on 30/10/2026 bandwidth hit 4.2 Go/day (23 Go in October, ~29 Cloudinary credits with storage + transformations) because lists load every waiting toy at 1600 px and the admin returns to the full list after each `confirm_verify`. Check the Cloudinary bandwidth curve after the v99 deploy (31/10/2026).

### Stylesheets

SCSS structured as `config/` (variables, Bootstrap overrides), `components/`, and `pages/`. Bootstrap variables are customized in `app/assets/stylesheets/config/_bootstrap_variables.scss`.

### Infrastructure

- PostgreSQL database (Solid Queue / Solid Cache / Solid Cable — database-backed, no Redis needed)
- Deployed on Heroku (`git push heroku master`, app `re-play`) — the Procfile release phase runs `db:migrate` automatically. Solid Queue runs inside Puma (`SOLID_QUEUE_IN_PUMA` config var).
- Error monitoring: Sentry (active only when `SENTRY_DSN` is set, and never in `rails runner` / `rails console` processes: a `heroku run` dyno gets the production env, so a failing throwaway script would show up as a production crash — locked by `test/initializers/sentry_initializer_test.rb`). Uptime: UptimeRobot on `GET /up`.
