# Feature Branch Workflow Skill

## When to use

- At the start of every new feature, before any file edits

## Rule

Never work directly from `main`/`master`. All work merges via PR.

## Workflow

1. Check branch: `git branch --show-current`
2. If on `main` or `master`, create and switch immediately:

   ```bash
   git checkout -b feature-name
   ```

3. Implement and test on the feature branch only.
4. Open a PR for review before merging.

## Local protection

The `pre-commit` hook blocks commits on `main`/`master` when hooks are enabled:

```bash
git config core.hooksPath .githooks
```

## GitHub branch protection (remote)

Protect the default branch on GitHub so direct pushes are rejected. As repo admin,
use Settings → Branches → Add rule, or see the API repo's
`.github/skills/feature-branch-workflow.md` for `gh api` commands (substitute
`main` for the branch name).
