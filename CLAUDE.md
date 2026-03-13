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
