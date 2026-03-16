# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
<<<<<<< HEAD
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
=======
# Start development server
bin/dev

# Run all tests
bin/rails test

# Run a single test file
bin/rails test test/models/toy_test.rb

# Run system tests
bin/rails test:system

# Lint
bin/rubocop

# Security scans
bin/brakeman --no-pager
bin/bundler-audit

# Database
bin/rails db:migrate
bin/rails db:seed
>>>>>>> 55f3750e962e82541cf5c00af4cf831fccbea384
```

## Architecture

<<<<<<< HEAD
Rails 8.1.2 app (Ruby 3.3.5) bootstrapped from the Le Wagon template. PostgreSQL database. Frontend uses Bootstrap 5.3 + Hotwire (Turbo + Stimulus) with importmaps (no Node/webpack).

### Domain Model

The app manages donated/refurbished toy inventory for a French resale operation:

- **Category** - top-level grouping (e.g. puzzle, jeu de société)
- **Box** - a physical donation box, belongs to a category, has weight and electronic flag
- **Toy** - individual toy, belongs to a box and category. Has condition fields (`clean`, `complete`, `playable`), `location` (defaults to "En attente de validation"), `price` (AI-suggested), `barcode`, and an attached `photo`
- **Action** - polymorphic audit log; records every user action on a Box or Toy with a `content` string. Also used to determine ownership for authorization.
- **User** - Devise authentication with an `admin` boolean flag

### AI Pricing

When a toy is created or updated, `ToysController#chat_response` calls RubyLLM with GPT-4o, passing the toy photo and a French-language prompt describing the toy's condition. The response (a number) is saved as `toy.price`. Requires an OpenAI API key in the environment.

### Authorization (Pundit)

All controllers require authentication (`authenticate_user!`). Pundit is enforced globally via `verify_authorized`/`verify_policy_scoped` after actions, with an exception for Devise and pages controllers.

Key authorization rules:
- **Edit/update** on Box or Toy: only the user who originally acted on it (`record.actions.where(user: user).any?`)
- **Destroy Toy / Verify Toy**: admin only (`user.admin?`)
- **Destroy Box**: the creator (via actions)

### Toy Verification Workflow

Toys start with `location = "En attente de validation"`. Admins can access `GET /toys/:id/verify` and `PATCH /toys/:id/confirm_verify` to complete a quality control check, which updates the toy's attributes and logs an action.

### File Storage

Active Storage + Cloudinary for toy photos. Requires `CLOUDINARY_URL` in the environment.

### Stylesheets

SCSS structured as `config/` (variables, Bootstrap overrides), `components/`, and `pages/`. Bootstrap variables are customized in `app/assets/stylesheets/config/_bootstrap_variables.scss`.
=======
<<<<<<< HEAD
### Domain Model

- **Box** — A physical donation box. Belongs to a `Category`, has many `Toys`. Status: `pending` | `empty`.
- **Toy** — A toy inside a box. Belongs to `Box` and `Category`, has one attached `photo`. Status: `pending` | `market` | `suppr` | `review`. Has an AI-generated `price` and a `vector(1536)` embedding column (pgvector).
- **Category** — Classification for both boxes and toys.
- **Action** — Polymorphic audit log. Any user action on a `Toy` or `Box` creates an `Action` record (content is a French string). Used by Pundit policies to determine ownership.
- **User** — Devise authentication with an `admin` boolean flag.

### Authorization (Pundit)

All controllers use Pundit. `ApplicationController` enforces `verify_authorized` / `verify_policy_scoped` on every action except pages and Devise. The `admin` flag controls privileged actions:
- Only admins can `verify` / `confirm_verify` a toy.
- `update?` and `destroy?` allow admins **or** users who have a prior `Action` on the record.

### AI Pricing (RubyLLM)

On toy `create` and `update`, `ToysController#chat_response` calls GPT-4o via the Azure GitHub Models inference endpoint. It sends a French prompt describing the toy's condition (clean/complete/playable) along with the toy's photo, and stores the returned integer as `price`. The API key is `ENV["GITHUB_KEY"]`.

### Routes

```
root → pages#home
/boxes          → BoxesController (index, show, new, create, edit, update, destroy)
/boxes/:id/toys → ToysController  (new, create — nested)
/toys           → ToysController  (index, show, edit, update, destroy)
/toys/:id/verify         GET   → verify form (admin only)
/toys/:id/confirm_verify PATCH → save verification result (admin only)
/about_us, /onboarding, /enjoue → PagesController (Pundit skipped)
```

### Frontend

Bootstrap + SCSS, organized as `config/`, `components/`, `pages/`. Stimulus JS with importmap (no Node/bundler). Forms use `simple_form` with Bootstrap integration.

### Infrastructure

- PostgreSQL with the `pgvector` extension (required for the `toys.embedding` column).
- Solid Queue / Solid Cache / Solid Cable (database-backed, no Redis needed).
- Deployed via Kamal.
=======
Rails 8.1 app generated from Le Wagon template. PostgreSQL database. Authentication via Devise. Authorization via Pundit. Frontend uses Bootstrap 5, Hotwire (Turbo + Stimulus), and importmap (no Node/webpack). Images stored via Active Storage + Cloudinary. Background jobs via Solid Queue.

### Domain Model

The app manages donated toy reconditioning and resale:

- **Category** — top-level toy category (name)
- **Box** — a donation box, belongs to Category, has weight and electronic flag
- **Toy** — belongs to Box and Category, has condition flags (clean, complete, playable), barcode, price (AI-suggested), location, and one attached photo
- **Action** — polymorphic audit log; any user action on a Box or Toy creates an Action record with a content string
- **User** — Devise auth, has `admin` boolean flag

### Authorization (Pundit)

Every controller action requires authorization. `ApplicationController` enforces `verify_authorized` (non-index) and `verify_policy_scoped` (index), skipped only for Devise and `pages#*`.

- All authenticated users can create boxes and toys
- `update?` / `destroy?` on Box/Toy: admin OR the user who created it (checked via `record.actions.where(user: user).any?`)
- `verify?` / `confirm_verify?` on Toy: admin only

### Toy Lifecycle

1. Toy is created with `location: "En attente de validation"` (scope: `Toy.waiting`)
2. After create/update, `chat_response` calls `RubyLLM` with GPT-4o to suggest a price based on a French prompt + toy photo
3. Admin verifies the toy via `GET /toys/:id/verify` → `PATCH /toys/:id/confirm_verify`, which updates location and moves it to `Toy.validated` scope
4. Toys index supports `?filter=validated` to toggle between waiting and validated views

### AI Pricing

`ToysController#chat_response` calls `RubyLLM.chat(model: "gpt-4o")` and passes a French-language system prompt describing the toy's condition (clean/complete/playable booleans) plus the toy photo. The response is expected to be a number only (average resale price in euros), which is saved as `toy.price`.
>>>>>>> 298bec46e461fdd2a19caffa1056c04c2d90d9a8
>>>>>>> 55f3750e962e82541cf5c00af4cf831fccbea384
