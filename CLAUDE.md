# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
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
```

## Architecture

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
