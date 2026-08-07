# 🚀 Guide Complet du Développeur Web Moderne
### Ta bible de développeur, chef de projet & consultant — Mise à jour pour l'ère de l'IA

---

## 📋 TABLE DES MATIÈRES

1. [Sécurisation des Variables Sensibles](#1-sécurisation-des-variables-sensibles)
2. [Collaboration & Git/GitHub](#2-collaboration--gitgithub)
3. [Configuration des Environnements](#3-configuration-des-environnements)
4. [Tests Automatisés & IA](#4-tests-automatisés--ia)
5. [RAG & Intégration de l'IA](#5-rag--intégration-de-lia)
6. [Accessibilité Web (WCAG AA)](#6-accessibilité-web-wcag-aa)
7. [Sécurité & Vulnérabilités Web](#7-sécurité--vulnérabilités-web)
8. [Gestion des Rôles & Permissions (RBAC)](#8-gestion-des-rôles--permissions-rbac)
9. [CI/CD — Déploiement Continu](#9-cicd--déploiement-continu)
10. [Monitoring & Observabilité](#10-monitoring--observabilité)
11. [Responsivité & Design System](#11-responsivité--design-system)
12. [Pérennité Technique & Veille](#12-pérennité-technique--veille)
13. [Checklist Finale — La Route du Pro](#13-checklist-finale--la-route-du-pro)
14. [Retours d'Expérience Production](#14-retours-dexpérience-production)

---

## 1. Sécurisation des Variables Sensibles

### 🎯 Principe fondamental
> **Ne jamais faire confiance aux données entrantes. Ne jamais exposer un secret.**

### 📁 Structure des fichiers
```
.env                  ← jamais committé (dans .gitignore)
.env.example          ← template sans valeurs sensibles, committé
.env.test             ← variables pour les tests
config/secrets.yml    ← jamais committé
```

### 🔧 Outils recommandés
| Outil | Usage |
|-------|-------|
| `dotenv` / `dotenv-rails` | Charger les variables d'environnement |
| `git-crypt` | Chiffrer des fichiers sensibles dans Git |
| `sops` (Mozilla) | Chiffrement de fichiers YAML/JSON |
| `Vault` (HashiCorp) | Gestion centralisée des secrets en prod |
| `AWS Secrets Manager` | Secrets managés dans le cloud AWS |
| `Dependabot` | Alertes automatiques sur les vulnérabilités |

### ✅ Bonnes pratiques
- Ajouter dans `.gitignore` : `.env`, `*.key`, `config/master.key`, `config/credentials.yml.enc`
- Utiliser des **variables d'environnement différentes** par environnement (dev/staging/prod)
- **Rotation régulière** des mots de passe, clés API et tokens (tous les 90 jours minimum)
- Appliquer le **principe du moindre privilège** : chaque service n'a accès qu'à ce dont il a besoin
- Ne jamais logger une variable sensible (`password`, `token`, `api_key`)
- Utiliser `Rails.application.credentials` avec master key en prod
- Scanner les secrets avant chaque commit avec `git-secrets` ou `truffleHog`

### 🔐 Exemple de configuration sécurisée
```ruby
# config/initializers/api_keys.rb
STRIPE_KEY = ENV.fetch("STRIPE_SECRET_KEY") { raise "STRIPE_SECRET_KEY manquant !" }
OPENAI_KEY = ENV.fetch("OPENAI_API_KEY")    { raise "OPENAI_API_KEY manquant !" }
```

```bash
# .env.example
DATABASE_URL=postgresql://user:password@localhost/myapp_development
STRIPE_SECRET_KEY=sk_test_XXXXXXXXXXXX
OPENAI_API_KEY=sk-XXXXXXXXXXXX
REDIS_URL=redis://localhost:6379/0
```

---

## 2. Collaboration & Git/GitHub

### 🌿 Stratégie de Branching (Git Flow)
```
main (production)
├── staging
├── develop
│   ├── feature/hotel-search-rag
│   ├── feature/user-authentication
│   ├── fix/booking-date-bug
│   └── hotfix/security-patch
```

### 📌 Convention de nommage des branches
| Préfixe | Usage |
|---------|-------|
| `feature/` | Nouvelle fonctionnalité |
| `fix/` | Correction de bug |
| `hotfix/` | Correctif urgent en prod |
| `refactor/` | Refactorisation de code |
| `chore/` | Tâches de maintenance |
| `docs/` | Documentation |

### 💬 Convention des commits (Conventional Commits)
```
feat: add hotel search with RAG
fix: correct booking date validation
refactor: extract payment service
docs: update API documentation
test: add RSpec tests for user model
chore: update dependencies
```

### 🔄 Workflow de Pull Request
1. `git checkout -b feature/ma-feature`
2. Développer + tester localement
3. `git add .` → `git commit -m "feat: description claire"`
4. `git push origin feature/ma-feature`
5. Ouvrir une **Pull Request** sur GitHub
6. Assigner 2-3 **reviewers**
7. Répondre aux commentaires et corriger
8. **Squash & Merge** après approbation
9. Supprimer la branche mergée

### 📝 Template de Pull Request
```markdown
## 🎯 Objectif
Décris ce que fait cette PR en 2-3 lignes.

## 📋 Changements
- [ ] Ajout de la feature X
- [ ] Tests unitaires ajoutés
- [ ] Documentation mise à jour

## 🧪 Comment tester ?
1. Aller sur /hotels
2. Rechercher "chambre calme avec vue"
3. Vérifier que les résultats RAG s'affichent

## 📸 Screenshots (si UI)
[Avant] [Après]

## ⚠️ Points d'attention
Mentionner les risques ou dépendances.
```

### 🗂️ Gestion de projet GitHub
- **Issues** : Une issue = une tâche, un bug, une question
- **Labels** : `bug`, `feature`, `urgent`, `good-first-issue`, `blocked`
- **Milestones** : Regrouper les issues par sprint/version
- **Projects (Kanban)** : `Backlog` → `In Progress` → `In Review` → `Done`
- **ADR (Architecture Decision Records)** : Documenter les décisions techniques importantes dans `/docs/adr/`

### 🤖 Outils de collaboration
| Outil | Usage |
|-------|-------|
| `danger` | Vérification automatique des PR |
| `pronto` | Analyse statique sur les PR |
| `CODEOWNERS` | Définir les responsables par fichier |
| `branch protection rules` | Bloquer les merges sans review |

---

## 3. Configuration des Environnements

### 🌍 Les 4 Environnements
| Environnement | Usage | Base de données |
|---------------|-------|-----------------|
| **Development** | Coder, débugger, tester manuellement | SQLite ou PostgreSQL local |
| **Test** | Exécuter les tests automatiques (RSpec) | PostgreSQL isolée, vidée avant chaque suite |
| **Staging** | Pré-production, validation client | PostgreSQL (clone de prod) |
| **Production** | Application en ligne | PostgreSQL optimisée |

### ⚙️ Configuration Rails par environnement
```ruby
# config/environments/production.rb
config.force_ssl = true
config.log_level = :info
config.cache_store = :redis_cache_store, { url: ENV["REDIS_URL"] }
config.active_job.queue_adapter = :sidekiq

# config/environments/development.rb
config.log_level = :debug
config.action_mailer.delivery_method = :letter_opener
config.bullet.enable = true  # Détection N+1 queries
```

### 🔒 Bonnes pratiques par environnement
- **Development** : Activer `Bullet` pour détecter les N+1 queries
- **Test** : Utiliser des factories (`FactoryBot`) plutôt que des fixtures
- **Staging** : Données anonymisées (jamais de vraies données clients)
- **Production** : HTTPS obligatoire, logs structurés, backups automatiques

### 📦 Variables d'environnement par contexte
```bash
# Staging
DATABASE_URL=postgresql://user:pass@staging-db/myapp_staging
RAILS_ENV=staging
LOG_LEVEL=info

# Production
DATABASE_URL=postgresql://user:pass@prod-db/myapp_production
RAILS_ENV=production
LOG_LEVEL=warn
RAILS_SERVE_STATIC_FILES=true
```

---

## 4. Tests Automatisés & IA

### 🔺 Pyramide des Tests
```
         /\
        /E2E\          ← Peu nombreux, lents (Capybara, Playwright)
       /------\
      /Intégra-\       ← Moyennement nombreux (Request specs, API tests)
     /  tion    \
    /------------\
   / Unitaires    \    ← Très nombreux, rapides (RSpec, Jest)
  /______________\
```

### 🧪 Outils de test recommandés
| Outil | Usage |
|-------|-------|
| `RSpec` | Tests unitaires et intégration Rails |
| `FactoryBot` | Génération de données de test |
| `Faker` | Données aléatoires réalistes |
| `Capybara` | Tests E2E navigateur |
| `VCR` | Enregistrer/rejouer les appels HTTP |
| `SimpleCov` | Couverture de code (viser 80%+) |
| `Shoulda Matchers` | Matchers expressifs pour Rails |

### 🤖 IA pour les tests
```
GitHub Copilot     → Suggère des cas de test en temps réel
ChatGPT/Claude     → Génère des specs complètes à partir d'un modèle
rspec-generator    → Génère des squelettes de tests
pronto             → Analyse statique sur les PR
```

### 📋 Exemple de spec bien structurée
```ruby
# spec/models/booking_spec.rb
RSpec.describe Booking, type: :model do
  # Associations
  describe "associations" do
    it { should belong_to(:user) }
    it { should belong_to(:room) }
  end

  # Validations
  describe "validations" do
    it { should validate_presence_of(:check_in_date) }
    it { should validate_presence_of(:check_out_date) }
  end

  # Méthodes métier
  describe "#total_price" do
    it "calcule le prix total en fonction du nombre de nuits" do
      room    = create(:room, price_per_night: 100)
      booking = create(:booking, room: room, check_in_date: Date.today, check_out_date: Date.today + 3)
      expect(booking.total_price).to eq(300)
    end
  end
end
```

### 🎯 Méthodologie TDD
```
1. RED   → Écrire un test qui échoue
2. GREEN → Écrire le minimum de code pour le faire passer
3. REFACTOR → Améliorer le code sans casser les tests
```

---

## 5. RAG & Intégration de l'IA

### 🧠 Qu'est-ce que le RAG ?
> **RAG = Retrieval-Augmented Generation**
> Technique qui enrichit les prompts d'un LLM avec des données contextuelles récupérées depuis une base de connaissances.

### 🔄 Fonctionnement du RAG
```
Utilisateur → Question
     ↓
Embedding (vectorisation de la question)
     ↓
Recherche vectorielle (pgvector, Pinecone, Weaviate)
     ↓
Récupération des documents pertinents
     ↓
Construction du prompt enrichi (question + contexte)
     ↓
LLM (GPT-4, Claude, Mistral) → Réponse précise
```

### 🏨 Fonctionnalités RAG pour une app de réservation
| Feature | Description |
|---------|-------------|
| **Assistant de recherche** | L'utilisateur décrit sa recherche en langage naturel, le RAG trouve les chambres correspondantes |
| **Comparateur intelligent** | Synthèse objective basée sur avis, équipements et historique des prix |
| **Concierge proactif** | Analyse le profil implicite du client pour suggérer des options hors critères stricts |
| **FAQ dynamique** | Réponses aux questions fréquentes basées sur la documentation de l'hôtel |

### ⚙️ Stack technique RAG (Rails)
```ruby
# Gemfile
gem "ruby-openai"          # Client OpenAI
gem "neighbor"             # pgvector pour Rails
gem "langchainrb"          # Framework LangChain pour Ruby

# Migration pgvector
class AddEmbeddingToRooms < ActiveRecord::Migration[8.0]
  def change
    enable_extension "vector"
    add_column :rooms, :embedding, :vector, limit: 1536
    add_index :rooms, :embedding, using: :ivfflat,
              opclass: :vector_cosine_ops
  end
end
```

```ruby
# Indexation des chambres
class RoomEmbeddingService
  def self.index(room)
    text = "#{room.name} #{room.description} #{room.amenities.join(', ')}"
    embedding = OpenAI::Client.new.embeddings(
      parameters: { model: "text-embedding-3-small", input: text }
    ).dig("data", 0, "embedding")
    room.update!(embedding: embedding)
  end
end

# Recherche sémantique
class RoomSearchService
  def self.search(query, limit: 5)
    query_embedding = embed(query)
    Room.nearest_neighbors(:embedding, query_embedding, distance: "cosine").limit(limit)
  end
end
```

### 🚀 Tendances IA à surveiller (2024-2025)
- **Agents IA** : LLM qui exécutent des actions (réserver, annuler, modifier)
- **Multimodal RAG** : Intégration d'images, sons, vidéos
- **Fine-tuning** : Personnaliser un LLM sur vos propres données
- **LLM locaux** : Ollama, LM Studio pour la confidentialité des données
- **Vector databases** : Pinecone, Weaviate, Qdrant, pgvector

---

## 6. Accessibilité Web (WCAG AA)

### 🎯 Les 4 principes WCAG (POUR)
| Principe | Description |
|----------|-------------|
| **P**erceptible | L'information doit être présentée de façon perceptible |
| **O**pérable | L'interface doit être utilisable au clavier |
| **U**niversellement compréhensible | Le contenu doit être lisible et prévisible |
| **R**obuste | Le contenu doit être interprété par les technologies d'assistance |

### ✅ Checklist WCAG AA essentielle
```
Images
  ☐ Attribut alt descriptif sur toutes les images
  ☐ Images décoratives : alt="" ou role="presentation"

Couleurs
  ☐ Ratio de contraste ≥ 4.5:1 pour le texte normal
  ☐ Ratio de contraste ≥ 3:1 pour les grands textes
  ☐ Information non véhiculée uniquement par la couleur

Navigation
  ☐ Navigation au clavier possible (Tab, Enter, Echap)
  ☐ Focus visible sur tous les éléments interactifs
  ☐ Skip links ("Aller au contenu principal")
  ☐ Ordre de tabulation logique

Formulaires
  ☐ Labels associés à chaque champ (<label for="...">)
  ☐ Messages d'erreur descriptifs et associés au champ
  ☐ Autocomplete approprié (name, email, tel...)

Structure
  ☐ Hiérarchie des titres respectée (h1 → h2 → h3)
  ☐ Landmarks ARIA (header, main, nav, footer)
  ☐ Langue déclarée (<html lang="fr">)

Médias
  ☐ Sous-titres pour les vidéos
  ☐ Transcription pour les audios
  ☐ Pas d'animation déclenchée automatiquement > 5s
```

### 🔧 Outils de vérification
| Outil | Usage |
|-------|-------|
| `axe DevTools` | Extension Chrome, analyse automatique |
| `WAVE` | Visualisation des erreurs d'accessibilité |
| `Lighthouse` | Audit Google intégré dans DevTools |
| `pa11y` | Tests d'accessibilité en CLI/CI |
| `Colour Contrast Analyser` | Vérification des ratios de contraste |

### 💻 Bonnes pratiques HTML accessibles
```html
<!-- ✅ Bouton accessible -->
<button type="button" aria-label="Fermer la modale">
  <svg aria-hidden="true">...</svg>
</button>

<!-- ✅ Image avec alt descriptif -->
<img src="hotel-paris.jpg" alt="Vue panoramique de l'hôtel Le Grand Paris, façade haussmannienne">

<!-- ✅ Formulaire accessible -->
<label for="check-in">Date d'arrivée</label>
<input type="date" id="check-in" name="check_in"
       aria-required="true"
       aria-describedby="check-in-hint">
<span id="check-in-hint">Format : JJ/MM/AAAA</span>
```

---

## 7. Sécurité & Vulnérabilités Web

### 🛡️ Top 10 OWASP — Les menaces principales

#### 1. SQL Injection
```ruby
# ❌ Dangereux
User.where("email = '#{params[:email]}'")

# ✅ Sécurisé (ActiveRecord paramétré)
User.where(email: params[:email])
User.where("email = ?", params[:email])
```

#### 2. Cross-Site Scripting (XSS)
```erb
<%# ❌ Dangereux — injection de script possible %>
<%= raw user.comment %>

<%# ✅ Sécurisé — Rails escape automatiquement %>
<%= user.comment %>
<%= sanitize user.comment, tags: %w[p b i em strong] %>
```

#### 3. CSRF (Cross-Site Request Forgery)
```ruby
# Rails protège automatiquement avec le token CSRF
# Vérifier que la protection est active :
class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception  # ← Doit être présent
end
```

#### 4. Insecure Direct Object Reference (IDOR)
```ruby
# ❌ Dangereux — accès direct par ID
@booking = Booking.find(params[:id])

# ✅ Sécurisé — scoped à l'utilisateur connecté
@booking = current_user.bookings.find(params[:id])
```

#### 5. Mass Assignment
```ruby
# ❌ Dangereux
User.update(params[:user])

# ✅ Sécurisé avec Strong Parameters
def user_params
  params.require(:user).permit(:name, :email, :phone)
  # Ne jamais inclure :role, :admin, :stripe_id...
end
```

### 🔧 Outils de sécurité Rails
| Outil | Usage |
|-------|-------|
| `brakeman` | Scanner de vulnérabilités statique |
| `bundler-audit` | Audit des gems vulnérables |
| `rack-attack` | Rate limiting et blocage d'IPs |
| `devise` | Authentification sécurisée |
| `pundit` | Autorisation et contrôle d'accès |

### 🔒 Headers de sécurité HTTP
```ruby
# config/initializers/security_headers.rb
SecureHeaders::Configuration.default do |config|
  config.x_frame_options      = "DENY"
  config.x_content_type_options = "nosniff"
  config.x_xss_protection     = "1; mode=block"
  config.hsts = { max_age: 1.year.to_i, include_subdomains: true }
  config.csp = {
    default_src: %w('self'),
    script_src:  %w('self' 'nonce-<%= request.content_security_policy_nonce %>'),
    img_src:     %w('self' data: https:)
  }
end
```

### 📋 Checklist Sécurité avant mise en prod
```
☐ HTTPS forcé (config.force_ssl = true)
☐ Pas de secrets dans le code ou les logs
☐ Strong Parameters sur tous les controllers
☐ Authentification et autorisation vérifiées
☐ Rate limiting configuré (rack-attack)
☐ brakeman sans warnings critiques
☐ bundler-audit sans vulnérabilités connues
☐ Headers de sécurité configurés
☐ Logs ne contenant pas de données sensibles
☐ Backups automatiques testés
```

---

## 8. Gestion des Rôles & Permissions (RBAC)

### 👥 Architecture des rôles
```
SUPER_ADMIN → Accès total (users, hôtels, config système)
HOTEL_ADMIN → Gère son hôtel (chambres, réservations, tarifs)
CLIENT      → Consulte, réserve, gère son profil
```

### 🔧 Implémentation avec Pundit
```ruby
# app/models/user.rb
class User < ApplicationRecord
  enum role: { client: 0, hotel_admin: 1, super_admin: 2 }
end

# app/policies/booking_policy.rb
class BookingPolicy < ApplicationPolicy
  def index?
    user.super_admin? || user.hotel_admin?
  end

  def show?
    user.super_admin? || record.user == user
  end

  def create?
    user.client?
  end

  def destroy?
    user.super_admin? || (record.user == user && record.future?)
  end
end

# app/controllers/bookings_controller.rb
class BookingsController < ApplicationController
  after_action :verify_authorized  # ← Garantit qu'aucune action ne passe sans vérification

  def show
    @booking = Booking.find(params[:id])
    authorize @booking
  end
end
```

### 🛡️ Bonnes pratiques RBAC
- Toujours utiliser `after_action :verify_authorized` dans les controllers
- Tester chaque policy unitairement avec RSpec
- Ne jamais afficher un bouton si l'action n'est pas autorisée : `if policy(@booking).destroy?`
- Logger les tentatives d'accès non autorisées
- Réviser les permissions régulièrement (principe du moindre privilège)

---

## 9. CI/CD — Déploiement Continu

### 🔄 Pipeline idéal
```
Push/PR
  ↓
🔍 Lint & Security scan (brakeman, rubocop, bundler-audit)
  ↓
🧪 Tests automatiques (RSpec, Capybara)
  ↓
🏗️ Build (assets, Docker image)
  ↓
🚀 Deploy Staging (automatique sur merge develop)
  ↓
✅ Smoke tests Staging
  ↓
🚀 Deploy Production (manuel ou automatique sur merge main)
  ↓
📊 Monitoring & Alertes
```

### ⚙️ Configuration GitHub Actions complète
```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
      - name: Brakeman Security Scan
        run: bundle exec brakeman -q --no-pager
      - name: Bundle Audit
        run: bundle exec bundler-audit check --update

  test:
    needs: security
    runs-on: ubuntu-latest
    env:
      RAILS_ENV: test
      DATABASE_URL: postgresql://postgres:postgres@localhost/myapp_test
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
        ports: ["5432:5432"]
        options: --health-cmd pg_isready --health-interval 10s
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
      - name: Setup DB
        run: bundle exec rails db:create db:migrate
      - name: Run RSpec
        run: bundle exec rspec --format progress
      - name: Coverage Report
        run: bundle exec simplecov

  deploy_staging:
    needs: test
    if: github.ref == 'refs/heads/develop'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Deploy to Staging
        run: git push heroku-staging develop:main

  deploy_production:
    needs: test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: production  # Requiert une approbation manuelle
    steps:
      - uses: actions/checkout@v4
      - name: Deploy to Production
        run: git push heroku main
```

### 🛠️ Outils CI/CD
| Outil | Usage | Points forts |
|-------|-------|-------------|
| **GitHub Actions** | CI/CD natif GitHub | Intégration parfaite, marketplace |
| **Heroku** | Hébergement PaaS | Simple, rapide pour les startups |
| **Railway** | Alternative Heroku moderne | Plus abordable, PostgreSQL inclus |
| **Render** | PaaS moderne | Free tier généreux |
| **AWS CodePipeline** | CI/CD AWS | Enterprise, très configurable |
| **Argo CD** | GitOps Kubernetes | Déploiement déclaratif |
| **Terraform** | Infrastructure as Code | Multi-cloud, reproductible |

---

## 10. Monitoring & Observabilité

### 📊 Les 3 piliers du monitoring
```
LOGS     → Que s'est-il passé ? (Datadog, Papertrail, Logtail)
MÉTRIQUES → Comment ça va ? (Grafana, Prometheus, Datadog)
TRACES   → Pourquoi c'est lent ? (Jaeger, Datadog APM, Skylight)
```

### 🔧 Stack de monitoring recommandée
| Outil | Usage | Quand l'utiliser |
|-------|-------|-----------------|
| **Sentry** | Capture des erreurs en temps réel | Toujours (gratuit pour petits projets) |
| **Datadog** | Logs, métriques, APM centralisés | Projets enterprise |
| **Grafana + Prometheus** | Dashboards et alertes | Projets avec Kubernetes |
| **Skylight** | Performance Rails spécifique | Apps Rails en production |
| **Pingdom** | Disponibilité et uptime | Surveillance 24/7 |
| **LogRocket** | Session replay utilisateur | Debug UX |

### ⚙️ Configuration Sentry pour Rails
```ruby
# Gemfile
gem "sentry-ruby"
gem "sentry-rails"
gem "sentry-sidekiq"  # Si tu utilises Sidekiq

# config/initializers/sentry.rb
Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"]
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
  config.traces_sample_rate = 0.2  # 20% des transactions tracées
  config.send_default_pii = false   # RGPD : ne pas envoyer les données perso

  config.before_send = lambda do |event, _hint|
    # Filtrer les erreurs bénignes
    return nil if event.exception&.values&.any? { |e| e.type == "ActionController::RoutingError" }
    event
  end
end
```

### 📈 Métriques clés à surveiller
```
Performance
  ☐ Temps de réponse moyen (objectif < 200ms)
  ☐ Taux d'erreur (objectif < 0.1%)
  ☐ Throughput (requêtes/seconde)
  ☐ Apdex score (satisfaction utilisateur)

Infrastructure
  ☐ CPU usage (alerte > 80%)
  ☐ Mémoire (alerte > 85%)
  ☐ Espace disque (alerte > 90%)
  ☐ Connexions DB actives

Business
  ☐ Nombre de réservations/heure
  ☐ Taux de conversion
  ☐ Erreurs de paiement
  ☐ Temps de chargement des pages clés
```

### 🚨 Configuration des alertes
```yaml
# Exemples d'alertes à configurer
alertes_critiques:
  - "Taux d'erreur 5xx > 1% pendant 5 minutes → PagerDuty + SMS"
  - "Site inaccessible depuis 2 régions → SMS immédiat"
  - "Erreur de paiement → Slack #incidents"

alertes_warning:
  - "Temps de réponse > 500ms → Slack #performance"
  - "CPU > 80% pendant 10 minutes → Slack #infra"
  - "Nouvelle erreur Sentry critique → Slack #bugs"
```

---

## 11. Responsivité & Design System

### 📱 Approche Mobile-First
```css
/* ✅ Mobile-First : partir du plus petit écran */
.container {
  padding: 1rem;          /* Mobile (320px+) */
}

@media (min-width: 768px) {
  .container {
    padding: 2rem;         /* Tablette */
  }
}

@media (min-width: 1024px) {
  .container {
    max-width: 1200px;
    margin: 0 auto;        /* Desktop */
  }
}
```

### 🎨 Design Tokens — Variables CSS
```css
:root {
  /* Couleurs */
  --color-primary:    #2563EB;
  --color-secondary:  #7C3AED;
  --color-success:    #16A34A;
  --color-error:      #DC2626;
  --color-text:       #1F2937;
  --color-bg:         #F9FAFB;

  /* Typographie */
  --font-size-sm:     0.875rem;
  --font-size-base:   1rem;
  --font-size-lg:     1.125rem;
  --font-size-xl:     1.25rem;

  /* Espacement */
  --spacing-xs:   0.25rem;
  --spacing-sm:   0.5rem;
  --spacing-md:   1rem;
  --spacing-lg:   2rem;
  --spacing-xl:   4rem;

  /* Bordures */
  --border-radius-sm: 4px;
  --border-radius-md: 8px;
  --border-radius-lg: 16px;
}
```

### 📐 Breakpoints standards
| Nom | Taille | Appareils |
|-----|--------|-----------|
| `xs` | < 480px | Petits mobiles |
| `sm` | 480px+ | Mobiles |
| `md` | 768px+ | Tablettes |
| `lg` | 1024px+ | Laptops |
| `xl` | 1280px+ | Desktops |
| `2xl` | 1536px+ | Grands écrans |

### ✅ Checklist Responsivité
```
☐ Navigation hamburger sur mobile
☐ Boutons tactiles ≥ 44x44px (recommandation Apple/Google)
☐ Police lisible sans zoom (minimum 16px)
☐ Images responsive (srcset, sizes, lazy loading)
☐ Tableaux scrollables horizontalement sur mobile
☐ Formulaires optimisés mobile (clavier adapté, autocomplete)
☐ Pas de hover-only interactions sur mobile
☐ Tests sur vrais appareils (pas seulement DevTools)
```

---

## 12. Pérennité Technique & Veille

### 📡 Stratégie de veille technologique
```
Quotidien (15 min)
  → Twitter/X : @dhh, @tenderlove, @matz_translator
  → Hacker News : hn.algolia.com
  → Dev.to, Medium (Ruby, Rails, IA)

Hebdomadaire
  → Ruby Weekly newsletter
  → This Week in Rails
  → TLDR Tech newsletter

Mensuel
  → Changelog des gems critiques (Rails, Devise, Sidekiq)
  → Dependabot alerts
  → CVE (Common Vulnerabilities and Exposures)

Trimestriel
  → Audit de sécurité complet (brakeman + bundler-audit)
  → Review des métriques de performance
  → Retrospective technique équipe
```

### 🔄 Gestion de la Dette Technique
```ruby
# Utiliser des tags TODO standardisés
# TODO: Refactoriser quand la gem X sera disponible
# FIXME: Bug connu, ticket #123
# HACK: Solution temporaire, à revoir avant v2
# OPTIMIZE: Performance à améliorer (N+1 détecté)
# SECURITY: Vérifier avant mise en prod
```

### 📦 Garder les dépendances à jour
```bash
# Vérifier les gems obsolètes
bundle outdated

# Mettre à jour de façon sécurisée
bundle update --conservative

# Audit de sécurité
bundle exec bundler-audit check --update

# Automatiser avec Dependabot (.github/dependabot.yml)
```

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "bundler"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 10
```

### 🚀 Préparation aux migrations majeures
```
Phase 1 — Préparation (3 mois avant)
  ☐ Lire les release notes de la nouvelle version
  ☐ Tester sur une branche feature dédiée
  ☐ Identifier les gems incompatibles
  ☐ Augmenter la couverture de tests à 80%+

Phase 2 — Migration (1 mois)
  ☐ Migrer en staging d'abord
  ☐ Corriger les dépréciations une par une
  ☐ Vérifier les performances après migration

Phase 3 — Production
  ☐ Déployer en heures creuses
  ☐ Monitoring renforcé 48h
  ☐ Plan de rollback prêt
```

### 🤖 L'IA dans votre workflow — Intégration progressive
```
Court terme (maintenant)
  → GitHub Copilot pour l'autocomplétion et les tests
  → ChatGPT/Claude pour les revues de code et debugging
  → IA pour générer les migrations et seeders

Moyen terme (6-12 mois)
  → RAG pour enrichir vos applications
  → Agents IA pour automatiser les tâches répétitives
  → LLM pour l'analyse des logs et la détection d'anomalies

Long terme (1-2 ans)
  → IA pour la génération automatique de tests
  → Monitoring prédictif basé sur le ML
  → Code review automatisé par IA
```

---

## 13. Checklist Finale — La Route du Pro

### 🏁 Avant de commencer un projet
```
Architecture & Setup
  ☐ README clair avec instructions de setup
  ☐ .gitignore configuré (secrets, logs, node_modules)
  ☐ .env.example à jour
  ☐ Linter configuré (RuboCop, ESLint, Stylelint)
  ☐ EditorConfig pour standardiser l'indentation
  ☐ Pre-commit hooks (Husky ou Overcommit)
  ☐ Branch protection rules sur main
  ☐ Template PR et Issue configurés
```

### 🛠️ Pendant le développement
```
Code Quality
  ☐ Commits atomiques et bien nommés (Conventional Commits)
  ☐ Tests écrits en même temps que le code (TDD)
  ☐ Pas de "TODO" sans ticket associé
  ☐ Revue de code systématique (minimum 1 reviewer)
  ☐ Documentation des décisions importantes (ADR)

Sécurité
  ☐ Pas de secrets dans le code
  ☐ Strong Parameters sur tous les endpoints
  ☐ Autorisation vérifiée sur chaque action (Pundit)
  ☐ Inputs utilisateur toujours validés et échappés
```

### 🚀 Avant chaque déploiement en production
```
Tests & Qualité
  ☐ Tous les tests passent (bundle exec rspec)
  ☐ Brakeman sans warnings critiques
  ☐ Bundler-audit sans CVE critiques
  ☐ RuboCop sans violations majeures
  ☐ Couverture de tests > 80%

Performance
  ☐ Pas de N+1 queries (Bullet activé)
  ☐ Index DB sur les colonnes fréquemment recherchées
  ☐ Assets compilés et minifiés
  ☐ Images optimisées (WebP, lazy loading)

Accessibilité
  ☐ Audit Lighthouse > 90 sur Accessibility
  ☐ Navigation clavier testée
  ☐ Contrastes vérifiés

Responsivité
  ☐ Testé sur mobile (iPhone SE + Galaxy S)
  ☐ Testé sur tablette (iPad)
  ☐ Testé sur desktop (1280px, 1920px)
```

### 📊 Après le déploiement
```
Monitoring
  ☐ Sentry sans nouvelles erreurs critiques (30 min)
  ☐ Métriques de performance normales
  ☐ Pas de pics d'erreurs dans les logs
  ☐ Tests fonctionnels en prod (smoke tests)
  ☐ Alertes configurées et testées
```

---

## 🎓 Ressources Essentielles

### 📚 Documentation officielle
- [Rails Guides](https://guides.rubyonrails.org/) — La référence absolue
- [OWASP Top 10](https://owasp.org/www-project-top-ten/) — Sécurité web
- [WCAG 2.1](https://www.w3.org/WAI/WCAG21/quickref/) — Accessibilité
- [Conventional Commits](https://www.conventionalcommits.org/) — Convention de commits
- [GitHub Actions Docs](https://docs.github.com/en/actions) — CI/CD

### 🎙️ Newsletters & Blogs
- [Ruby Weekly](https://rubyweekly.com/)
- [This Week in Rails](https://rails-weekly.ongoodbits.com/)
- [TLDR Tech](https://tldr.tech/)
- [Thoughtbot Blog](https://thoughtbot.com/blog)
- [The Pragmatic Engineer](https://newsletter.pragmaticengineer.com/)

### 🛠️ Outils indispensables
```
Développement    → VS Code + GitHub Copilot, TablePlus, Insomnia
Tests            → RSpec, FactoryBot, Capybara, SimpleCov
Sécurité         → Brakeman, Bundler-audit, OWASP ZAP
Performance      → Bullet, Rack Mini Profiler, Skylight
Monitoring       → Sentry, Datadog ou Grafana, Pingdom
Déploiement      → GitHub Actions, Heroku/Railway/Render
Accessibilité    → axe DevTools, WAVE, Lighthouse
IA               → GitHub Copilot, ChatGPT, Claude
```

---

## 14. Retours d'Expérience Production

> Section alimentée par les audits et migrations réels des projets (RE-PLAY, COSTLY).
> Ce sont les pièges rencontrés **en vrai**, avec leur solution vérifiée.

### 🌐 Domaines & HTTPS — Migration DNS vers Cloudflare (août 2026, costly.fr)

**Le problème** : chez OVH, le domaine nu (`monsite.fr` sans `www`) ne peut pas pointer
vers Heroku (pas d'enregistrement ALIAS à l'apex). La « redirection visible » d'OVH
fonctionne en HTTP mais **n'a pas de certificat SSL** → `https://monsite.fr` est en
erreur pour tout visiteur qui tape le domaine nu (les navigateurs tentent HTTPS d'abord).

**La solution** : déléguer les DNS à Cloudflare (plan Free) qui sert le HTTPS de l'apex
et redirige vers `www`. Runbook vérifié :

1. **Inventaire complet de la zone** avant tout : MX, SPF/TXT, CNAME mail
   (`imap`, `smtp`, `pop3`, `autoconfig`, `autodiscover`), SRV. Oublier les MX = plus d'emails.
2. Créer le site dans Cloudflare (plan Free) → il scanne et importe la zone. **Vérifier
   l'import contre l'inventaire.**
3. **Proxy status** : nuage gris (DNS only) sur tous les CNAME mail (le proxy Cloudflare
   ne parle que HTTP — proxifier `imap`/`smtp` casse les clients mail) et sur `www` si
   Heroku gère déjà son certificat. Nuage orange (Proxied) uniquement sur l'apex.
4. **SSL/TLS → Full (strict)** ; règle de redirection via le template
   **« Redirect from Root to WWW »** (301, cocher *Preserve query string*).
5. **⚠️ DNSSEC — LE piège qui met tout par terre** : OVH l'active par défaut sur les
   `.fr`. Changer les serveurs DNS sans l'avoir désactivé = domaine entier en panne
   (SERVFAIL chez tous les résolveurs validants), web **et** emails. Ordre impératif :
   désactiver DNSSEC chez OVH → **attendre la purge du DS au registre** (vérifiable en
   interrogeant les serveurs AFNIC, ex. `d.nic.fr` ; de quelques minutes à ~1 h) →
   seulement ensuite changer les serveurs de noms.
6. Basculer les serveurs de noms chez OVH → « Check nameservers now » dans Cloudflare
   → vérifier `https://apex` (301 → www), les MX, et le monitor d'uptime.
7. **Après 48 h de propagation** : réactiver DNSSEC (côté Cloudflare cette fois, puis
   recopier le DS chez OVH via l'onglet « DS Records ») et résilier les options DNS
   payantes OVH devenues inutiles (Anycast).

### 🚀 Spécificités Heroku (Rails 8)

- **Release phase obligatoire** dans le `Procfile`, sinon les migrations sont manuelles
  (et un jour oubliées) :
  ```
  web: bin/rails server -p ${PORT:-5000} -e $RAILS_ENV
  release: bin/rails db:migrate
  ```
- **`config.assume_ssl` doit rester `false` sur Heroku** : le routeur transmet
  correctement `X-Forwarded-Proto`. L'activer fait croire à Rails que les requêtes HTTP
  en clair sont déjà en HTTPS → **la redirection de `force_ssl` ne se déclenche plus**
  (vécu : site servi en clair alors que `force_ssl = true`).
- **Healthcheck** : vérifier que `get "up" => "rails/health#show"` existe bien dans
  `routes.rb` (facile à supprimer par erreur en nettoyant le template — la config
  `silence_healthcheck_path` orpheline ne préviendra pas). C'est le point d'entrée
  d'UptimeRobot.
- **Sentry + releases** : activer `heroku labs:enable runtime-dyno-metadata` pour que
  Sentry associe les erreurs à la version déployée.

### 📡 Monitoring minimal viable (gratuit, validé de bout en bout)

- **Sentry** : initializer conditionné à `ENV["SENTRY_DSN"]` (rien ne part en
  dev/test/CI), `send_default_pii = false` (RGPD), `traces_sample_rate` 0.1,
  exclure `ActionController::RoutingError` (bruit des bots).
- **UptimeRobot** : monitor HTTP(S) sur `/up` toutes les 5 min.
- **Valider la chaîne complète** : déclencher une erreur volontaire en prod
  (`heroku run rails runner 'Sentry.capture_exception(StandardError.new("test"))'`)
  et vérifier la réception de l'**email**. Un monitoring non testé n'existe pas.

### 🧪 Pièges CI (GitHub Actions + Rails)

- **RuboCop** : redéfinir `AllCops.Exclude` **écrase** la liste par défaut. En CI les
  gems sont vendorées dans `vendor/bundle` → sans re-lister `vendor/**/*`, RuboCop
  linte tout Rails (des milliers de fausses offenses qui n'apparaissent pas en local).
- **Eager loading** : la CI exporte `CI=1` → Rails eager-load tout en test. Des erreurs
  invisibles en local (ex. un `skip_after_action` référençant un callback renommé)
  n'explosent **que** sur GitHub. Reproduire avec `CI=1 bin/rails test` avant de pousser.
- **Tests système** : après `click_button` (connexion), **attendre la redirection**
  (`assert_current_path`) avant tout `visit` suivant, sinon course entre les deux
  navigations → échec intermittent.
- **Pannes GitHub Actions** : un incident peut faire échouer des jobs en masse
  (« Service Unavailable ») ou **perdre silencieusement l'événement de push** (aucun
  run créé). Avant de déboguer son code : vérifier qu'un run existe pour le bon SHA,
  et relancer au besoin avec un commit vide.

### 🔐 Pundit — câblage global robuste

`after_action :verify_authorized, except: :index` + `verify_policy_scoped, only: :index`
casse dès qu'un controller n'a pas d'action `index` (avec
`raise_on_missing_callback_actions` activé en test). Préférer un callback unique sans
`only:`/`except:` qui dispatch sur `action_name` :

```ruby
after_action :verify_pundit_authorization, unless: :skip_pundit?

def verify_pundit_authorization
  action_name == "index" ? verify_policy_scoped : verify_authorized
end
```

Et toujours un `rescue_from Pundit::NotAuthorizedError` → redirection + alerte
(sinon : erreur 500 pour un simple accès refusé).

### 🖨️ Piège navigateur — impression PDF sous Windows 11

Chrome/Edge + imprimante virtuelle Windows (« Microsoft Print to PDF », OneNote) :
certains glyphes sortent doublés/en gras (les « l » notamment), **quelle que soit la
police** — bug Chromium/Windows 11, l'aperçu est correct, seul le PDF final est touché.
Solution à communiquer aux utilisateurs : choisir la destination **« Fichier PDF » /
« Enregistrer au format PDF »** (moteur interne de Chrome). Aucun correctif CSS possible.

---

*Dernière mise à jour : août 2026 | Maintenu avec ❤️ par et pour les développeurs qui font du bon travail.*
