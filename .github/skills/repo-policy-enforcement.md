# Repo Policy Enforcement Skill

**Shared rules for secure-bidding-api and secure-bidding-app.**

## Hard rules (always)

1. **No AI co-author trailers** — see [commit-authorship](commit-authorship.md)
2. **Hooks enabled** — `git config core.hooksPath .githooks` once per clone

## Relaxed rules (current)

1. **Direct commits on default branch** — allowed (`main` / `master`)
2. **No PR required** for every change
3. **CI `check_trailers`** — warning only, does not fail the workflow
4. **No force-push** on default branch unless the user explicitly requests history rewrite

## Enforcement parity

| Layer | API | App | Same? |
| --- | --- | --- | --- |
| `pre-commit` hook | markdownlint | markdownlint | Yes |
| `prepare-commit-msg` | Strips AI trailers | Strips AI trailers | Yes |
| `commit-msg` | Blocks AI trailers | Blocks AI trailers | Yes |
| `policy-check.yml` | Advisory `check_trailers` | Advisory `check_trailers` | Yes |
| Default branch | `master` | `main` | Name differs only |

## One-time setup (each clone)

```bash
git config core.hooksPath .githooks
chmod +x .githooks/pre-commit .githooks/prepare-commit-msg .githooks/commit-msg
```

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| Commit rejected for AI trailer | Remove `Co-authored-by` lines; hook should strip on retry |
| CI warning about trailers | Rewrite or amend commits to remove trailers |
| Hooks not running | Run `git config core.hooksPath .githooks` |
