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
