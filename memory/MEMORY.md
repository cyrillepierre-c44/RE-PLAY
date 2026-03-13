# RE-PLAY Project Memory

## Stack
Rails 8.1, PostgreSQL, Devise, Pundit, Bootstrap 5, Hotwire/Turbo/Stimulus, importmap (no Node/webpack), Active Storage + Cloudinary, Solid Queue/Cache/Cable, ruby_llm gem (GPT-4o pour pricing IA).

## Design System (post-redesign)
- Primary font: Fredoka One (titres) + Nunito (corps) — Google Fonts importés dans `_fonts.scss`
- Palette: coral `#FF6B35` (primary), yellow `#FFD166` (warning), mint `#0CC9A3` (success), sky `#4CC9F0` (info), navy `#1A2B4A` (texte), cream `#FFFBF4` (background)
- Navbar class: `.navbar-replay` (remplace `.navbar-lewagon`)
- Flash: `.flash-container` + `.flash-toast` (fixed bottom-right, animé)
- Cards: `.toy-card`, `.box-card`, `.detail-card`, `.stat-card`
- Forms: `.form-card` + `.form-card-header` + `.form-card-body` wrapper
- Auth pages: `.auth-page` + `.auth-card`
- Filter tabs: `.filter-tabs` + `.filter-tab`

## SCSS structure
```
config/_fonts.scss        ← Fredoka One + Nunito
config/_colors.scss       ← variables couleurs
config/_bootstrap_variables.scss ← overrides Bootstrap
components/_navbar.scss
components/_alert.scss    ← flash toasts
components/_cards.scss    ← toy-card, box-card, detail-card, stat-card
components/_buttons.scss
components/_badges.scss   ← badge-waiting, badge-validated, condition-pill
components/_forms.scss    ← form-card, auth-card, filter-tabs, form-check-custom
pages/_home.scss          ← home-hero, stat-card, quick-action-card
pages/_auth.scss          ← dotted background
```

## Domain
- Category → Box → Toy (polymorphic Action pour audit log)
- User.admin? booléen pour droits verify/confirm_verify sur Toy
- Toy.waiting = location "En attente de validation", Toy.validated = le reste
- chat_response appelle GPT-4o via ruby_llm après create/update d'un Toy
