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

- **Category** — top-level grouping (e.g. puzzle, jeu de société). `mixed` (boolean) flags a box-only category: **« Grosses pièces »** = a 2 m roll mixing bulky toys of different categories. Such a category can be picked for a Box, never for a Toy (`Category.for_toys`, validation on Toy), and a toy created from that box inherits **no** category (`Box#toy_category` → nil, `toys.category_id` is nullable): the operator must choose it in the form; until then badges show « À choisir » (`category_icon` / `category_name` helpers — never call `toy.category.name` directly).
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
- **Mon profil** (`Users::RegistrationsController#update_resource`): only the password can be changed (current password required). The e-mail is assigned by Enjoué and used as the identifier in the action history, so it is not editable and any `email` param is dropped — a change is done in the database by Cyrille. Reason: on 05/11/2026 a colleague on a shared, still-logged-in device replaced another account's e-mail with her own, making that account "disappear" from the list.

### Toy Lifecycle

0. **Brouillon (`status: draft`, concern `Draftable`, jouets *et* caisses)** — the J/C number is reserved as soon as creation starts (`toys#new` saves the toy; `boxes#create` with `new_flow`), because several people label toys/boxes in parallel. The record stays `draft` until the form is saved once (`toys#update` / `boxes#update` → `pending`). A draft counts nowhere (`not_draft` in lists, dashboard, box deletion check, `toggle_empty?`), has no show page (redirects to `edit?new=true`), and is only shown to its creator and admins in the dashed « À terminer » strip (`shared/_drafts`) with resume + trash. The in-app back arrow of the creation form is a `DELETE` that hard-deletes the draft and its actions (`discard_draft!`, "fausse manip" — the number is lost, gaps in numbering are expected); browser back / closed tab leaves the draft, and `PurgeDraftsJob` (`config/recurring.yml`, daily) removes drafts older than 7 days. Decided with Cyrille on 12/11/2026: no confirmation screen on the back arrow — to keep a number, press ✓. Toys/boxes abandoned before that date were left as `pending` (not converted).
1. Once saved, the toy is `pending` with `location: "En attente de validation"` (scope: `Toy.waiting`)
2. After create/update, a `PriceiaJob` calls the Claude API (Haiku 5.5) to suggest a price based on a French prompt + toy photo
3. Admin verifies the toy via `GET /toys/:id/verify` → `PATCH /toys/:id/confirm_verify` (see **Suivi qualité** below), which on acceptance sets the location and moves it to `Toy.validated` scope
4. Toys index supports `?filter=validated` to toggle between waiting and validated views
5. **Listes paginées** (`toys#index`, `boxes#index`) : 48 cartes par page (`ApplicationController#paginate`, `shared/_pager`). Raison : le 16/11/2026 la liste « Attente » comptait ~1 900 jouets → 5 s de rendu et 3,8 Mo ; paginée, ~0,13 s et 131 Ko. La recherche par numéro et la fiche d'une caisse ne sont pas paginées (`boxes#show` précharge photos et catégories).

### Suivi qualité (CQ) — règles décidées avec Enjoué le 16/11/2026

Vocabulaire du client : **TRI** = atelier qui remplit les caisses (le créateur de la caisse répond de son contenu) ; **VALO** = valorisation d'un jouet par un opérateur ; **CQ** = contrôle qualité par un admin ; **Bon du 1er coup** = l'inverse du taux de non-conformité. Opérateurs et CQ travaillent sur smartphone.

- **`QualityControl`** (PORO) applique chaque décision du CQ et crée un **`QualityCheck`** (une ligne par décision : `round`, `decision`, `causes[]`, `cq_comment`, `operator_comment` figé, `operator`, `checker`, `reworked_at`, `resolved_at`). Un contrôle `refused` est une non-conformité.
- **Tours** : 1er tour → `market`, ou refus → statut `review` (« CQ refusé »). L'opérateur retraite en enregistrant le formulaire (`toys#update`) : le jouet repasse `pending`, `reworked_at` est posé. 2e tour → `market`, ou 2e refus → statut **`arbitrage`** (« À arbitrer ») : la boucle s'arrête, un admin choisit la destination. Pas de 3e tour.
- **Destinations finales** : `market` (prêt), vendu (`sold`), `suppr` (rebut), **`vrac`** (pièces pour compléter d'autres jouets), **`don`**. Vrac/don/rebut sont décidables dès le 1er tour.
- **Commentaire CQ obligatoire** à chaque refus et pour tout ce qui n'est pas une mise en vente au 1er tour (2e tour même validé, arbitrage, vrac, don, rebut). Un refus exige au moins une cause.
- **Causes** : `QualityCause::CQ` (11 causes, unifiées entre le tableur du client et les anciens critères) et `QualityCause::DISCARD` (13 causes du « jeter directement », stockées dans `toys.discard_causes`). `tri: true` = le TRI aurait dû écarter le jouet (affiche « Objets non acceptés au TRI ») → compte contre le Bon du 1er coup du TRI ; `tri: false` (incomplet, sale, langue, panne non électronique) = le TRI ne le vérifie pas. Les clés sont en base : ne pas les renommer. Sélecteur à pictogrammes + légende dépliable : `shared/_cause_chips`.
- **Commentaires par tour** : les tours passés s'affichent grisés et en lecture seule (`toys/_quality_history`) ; au refus, `toy.operator_note` est vidé pour libérer la note du tour suivant. Une zone vide en lecture seule affiche « Aucun commentaire », un champ à remplir a un placeholder commençant par « Vide — ».
- **Délais en jours ouvrés** (`WorkingDays`, lundi–vendredi, fériés ignorés). Bandeau « CQ refusé » orange, **rouge** au-delà de `QualitySetting.current.red_after_days` (3 par défaut) : `cq_banner`. Liste « À reprendre » (`/toys?filter=review`) triée du plus ancien refus au plus récent (FIFO) ; un opérateur qui se connecte avec des CQ refusés à sa charge y arrive directement (`after_sign_in_path_for`).
- **Responsable d'un jouet** : `toys.operator_id` = valorisateur (créateur), à qui la non-conformité est comptée ; `toys.assignee_id` = personne à qui un admin a **confié** le jouet (opérateur absent, `PATCH /toys/:id/reassign`, admins seulement) — elle y a alors accès (`ToyPolicy#involved?`) et le voit dans « À reprendre » (`Toy.held_by`).
- **Objectifs** réglables : `QualitySetting` (ligne unique : `target_valo`, `target_tri`, `red_after_days`, `min_sample`). **Seuil de fiabilité** `min_sample` (20) : en dessous de ce nombre de jouets contrôlés, aucun pourcentage n'est affiché (« 9 sur 10 » à la place) — atelier, opérateur, semaine de la courbe. Un jouet est compté à la date de son contrôle, pas de sa valorisation : sur une journée (`QualityDashboard#daily?`), le tableau par opérateur devient un suivi du stock (NC ouvertes, refus reçus, retraités) au lieu d'un taux. Décidé avec Cyrille le 16/11/2026.
- **Tableau de bord** (`/dashboard`, admins) : volet qualité calculé par `QualityDashboard` (définitions des indicateurs en tête du fichier), rendu par `pages/_quality`. Bandeau « En ce moment » indépendant de la période ; Bon du 1er coup VALO et TRI avec objectif ; causes, opérateurs, matrice opérateur × cause, TRI par créateur de caisse. Tout chiffre cliquable charge `GET /dashboard/quality_detail` dans le turbo-frame `quality-detail`, placé dans une fenêtre modale (plein écran sur téléphone) ouverte par le contrôleur Stimulus `quality-detail` — qui charge aussi à la main les liens SVG de la courbe, que Turbo n'intercepte pas. La fenêtre a son bouton « Imprimer cette liste ». Objectifs : `PATCH /quality_setting`. Impression/PDF : `@media print` dans `pages/_dashboard.scss` (sauts de page à affiner avec le client). Périodes : `today`, `prev_day` (« Hier » = jour ouvré précédent), `last_week`, `four_weeks`, `month`, `custom`.
- **Procédures** (`/procedures`, menu du compte) : trois modes d'emploi lisibles dans l'appli et imprimables en PDF — `operateur` (tous ; une page A4 d'affiche + une page « en images »), `controle-qualite` et `tableau-de-bord` (admins). Vues dans `pages/procedures/`, styles dans `pages/_onboarding.scss`. Les listes de causes et les seuils y sont lus en direct (`QualityCause`, `QualitySetting`). Les **captures d'écran** (`app/assets/images/procedures/`) montrent des comptes et jouets fictifs : `bin/procedures-captures` recrée la base `re_play_demo` (`procedures:seed_demo`, refusé hors d'une base `_demo`), lance l'appli et un Chrome sans écran (Docker `chromedp/headless-shell`, Node 22+) puis exécute `lib/demo/captures.mjs`. À relancer quand un écran montré change. Impression : page nommée `document` (marges + pied de page), car `_projet.scss` impose `@page { margin: 0 }` à tout le site.
- **Historique** : `bin/rails quality:backfill` (`DRY_RUN=1` pour un essai) reconstruit les `QualityCheck` d'avant le 16/11/2026 depuis le journal des actions — causes approximatives, pas de date de retraitement. À lancer une fois après la mise en production ; sans danger à relancer.
- `admin_comment` ne sert plus au CQ (ancien commentaire affiché seulement si le jouet n'a aucun `QualityCheck`) ; il porte toujours la note « prix IA impossible ».

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
/toys/:id/reassign       PATCH → confier le jouet à un autre opérateur (admin only)
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
