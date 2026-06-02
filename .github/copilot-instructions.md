# Copilot Instructions: Secure Bidding App

> **#1 RULE — COMMIT AUTHORSHIP**
> Never add `Co-authored-by` trailers for Copilot, Cursor, or any AI tool.
> Hooks strip/block them (course rule). Read `.github/skills/commit-authorship.md`
> before every commit.

## How Copilot, skills, hooks, and CI relate

| Layer | What it does | When it runs |
| --- | --- | --- |
| **This file** | Copilot reads it automatically in this repo | Every Copilot session |
| **Skills** (`.github/skills/`) | Playbooks Copilot reads when pointed to them | When a task matches the trigger |
| **Git hooks** (`.githooks/`) | `prepare-commit-msg` + `commit-msg` strip/block Copilot and Cursor | After hook setup |
| **GitHub Actions** | Advisory trailer check; see [repo-policy-enforcement](.github/skills/repo-policy-enforcement.md) | Every push and PR |

Copilot does **not** automatically read every skill file — it follows this index.
Workflows do **not** instruct Copilot; they **enforce** rules after push.
Hooks only work locally after: `git config core.hooksPath .githooks`

Full parity table: [repo-policy-enforcement](.github/skills/repo-policy-enforcement.md)

## Hard Rules

1. **Commit authorship** — See skill: [commit-authorship](.github/skills/commit-authorship.md)
2. **Weekly scope** — See [weekly-scope-gating](.github/skills/weekly-scope-gating.md) and
   `.github/weekly-specifications/week-N.md`
3. **Branches** — Direct commits on `main` are OK (relaxed). Use feature branches
   for large work. See [feature-branch-workflow](.github/skills/feature-branch-workflow.md)
4. **Test-first** — See [tdd-mastery](.github/skills/tdd-mastery.md)

## Skill Index

| Priority | Trigger | Skill |
| --- | --- | --- |
| **#1** | Before every commit | [commit-authorship](.github/skills/commit-authorship.md) |
| Required | Clone setup / CI failures | [repo-policy-enforcement](.github/skills/repo-policy-enforcement.md) |
| Required | Every task start | [weekly-scope-gating](.github/skills/weekly-scope-gating.md) |
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

- `.github/skills/encryption-ui.md`
- `.github/skills/role-based-authorization.md`
- `.github/skills/payment-flow.md`
- `.github/skills/bid-submission-flow.md`

## Commands

```bash
git config core.hooksPath .githooks    # Run once per clone
bundle exec rackup -p 9292
bundle exec rake spec
npx markdownlint-cli2 "**/*.md" "#node_modules"
```

## Architecture (reference)

Server-rendered Roda + Slim over API at `http://localhost:3000/api/v1`.
Controllers in `app/controllers/`, services in `app/services/`, views in
`app/presentation/views/`.
