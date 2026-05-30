# Commit Authorship Skill

**Highest-priority skill.** Read this before every commit.

## Hard rule (course policy — always enforced)

Never include AI co-author trailers in commit messages:

```text
Co-authored-by: GitHub Copilot
Co-authored-by: Cursor
Co-authored-by: OpenAI
```

The developer is the sole author. Agents must **not** add these lines when committing.

## Before every commit

1. Run tests (`bundle exec rake spec`) when code changed.
2. Write a short message with **no** `Co-authored-by` lines for any AI tool.
3. Commit; hooks strip accidental trailers and block if any remain.

## Local hooks (enable once per clone)

```bash
git config core.hooksPath .githooks
chmod +x .githooks/pre-commit .githooks/prepare-commit-msg .githooks/commit-msg
```

| Hook | Effect |
| --- | --- |
| `prepare-commit-msg` | Removes AI `Co-authored-by` lines before the message is saved |
| `commit-msg` | Fails the commit if AI trailers are still present |
| `pre-commit` | Markdownlint on staged `.md` only (does **not** block `main`) |

## CI (relaxed)

`policy-check.yml` prints a **warning** if trailers appear in pushed commits; it does
not fail the workflow. Fix history if a warning appears.

## Agent commits

When the user asks you to commit and push: commit on `main` is allowed; never use
`--no-verify` to bypass trailer hooks; never force-push default branches unless the
user explicitly requests a history rewrite.

See [repo-policy-enforcement](repo-policy-enforcement.md) for the full table.
