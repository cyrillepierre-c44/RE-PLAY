# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

RE-PLAY is a Rails 8 application for managing refurbished toy donations. Workers scan donated toys into boxes, and admins verify/price toys using AI before listing them for sale. Generated with the [Le Wagon rails-templates](https://github.com/lewagon/rails-templates).

## Commands

```bash
# Start development server (Rails + assets)
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
