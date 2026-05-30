# Copilot Instructions: Secure Bidding App

## Hard Rules (read first)

1. **Weekly scope** — Implement only what the current week requires. See
   `.github/weekly-specifications/week-N.md` and
   `.github/skills/weekly-scope-gating.md`.
2. **Commit authorship** — Never add AI co-author trailers. Developer runs the
   final commit. See `.github/skills/commit-authorship.md`.
3. **Feature branches** — Never edit on `main`/`master`. See
   `.github/skills/feature-branch-workflow.md`.
4. **Test-first** — Write a failing test before implementation code. See
   `.github/skills/tdd-mastery.md`.

## Skill Index

| Priority | Trigger | Skill |
| --- | --- | --- |
| Required | Every task start | [weekly-scope-gating](.github/skills/weekly-scope-gating.md) |
| Required | Before commits | [commit-authorship](.github/skills/commit-authorship.md) |
| Required | New feature start | [feature-branch-workflow](.github/skills/feature-branch-workflow.md) |
| Required | Behavior changes | [tdd-mastery](.github/skills/tdd-mastery.md) |
| High | Routes, services, views | [controller-service-view](.github/skills/controller-service-view.md) |
| High | API calls | [api-integration](.github/skills/api-integration.md) |
| High | Login/session | [session-authentication](.github/skills/session-authentication.md) |
| Medium | Form feedback | [flash-messages](.github/skills/flash-messages.md) |
| Medium | Role visibility | [role-based-ui](.github/skills/role-based-ui.md) |
| Medium | Task handoff | [delivery-checkpoint](.github/skills/delivery-checkpoint.md) |
| Medium | `.md` edits | [markdown-linting](.github/skills/markdown-linting.md) |

### Future capability (reference only)

Use only when the weekly spec explicitly requires them:

- `.github/skills/encryption-ui.md`
- `.github/skills/role-based-authorization.md`
- `.github/skills/payment-flow.md`
- `.github/skills/bid-submission-flow.md`

## Commands

```bash
bundle install
bundle exec rackup -p 9292          # Dev server (localhost:9292)
bundle exec rake spec               # Tests
npx markdownlint-cli2 "**/*.md" "#node_modules"   # After .md edits
```

## Backend API

REST API at `http://localhost:3001/api/v1` (see secure-bidding-api repo).

Key resources: accounts, projects, bid_submissions, payments, memberships.

## Architecture (reference)

Server-rendered Roda + Slim app — thin presentation layer over the API.

| Layer | Location | Role |
| --- | --- | --- |
| Controllers | `app/controllers/` | Routes, session, render/redirect |
| Services | `app/services/` | Business logic and API calls via `ApiClient` |
| Views | `app/presentation/views/` | Slim templates and partials |
| Config | `config/environments.rb` | Session secret, API URL |

**Stack:** roda, slim, rack-session, http, figaro, puma; test with rack-test +
minitest.

**Secrets:** copy `config/secrets.example.yml` → `config/secrets.yml`; never
commit real secrets.

**Reference:** https://github.com/ISS-Security/tyto2026-app (architectural guide
only — do not exceed current week scope).
