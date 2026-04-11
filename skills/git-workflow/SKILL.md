---
name: git-workflow
description: "Git workflow conventions for branch naming, commit messages, PR workflow, and merge strategies. Use when creating branches, writing commits, opening PRs, or establishing git conventions for a project. Triggers on git operations, commit message writing, or repository workflow setup."
---

# Git Workflow

Standardized git workflow conventions for consistent, readable project history.

## When to Use

Use this skill when:

- Creating branches or writing commit messages
- Opening or reviewing pull requests
- Setting up git workflow for a new project
- Resolving merge conflicts or choosing merge strategies

Do NOT use this skill when:

- The project has explicit, documented git conventions that differ
- The user specifies a different convention

## Branch Naming

```
<type>/<short-description>

Types:
  feat/     — New feature
  fix/      — Bug fix
  refactor/ — Code refactoring
  docs/     — Documentation changes
  test/     — Adding or updating tests
  chore/    — Maintenance, dependencies, CI
  hotfix/   — Urgent production fix
```

```
Good:
  feat/user-authentication
  fix/login-redirect-loop
  refactor/extract-payment-service
  docs/api-endpoints

Bad:
  feature-123
  john/working-on-stuff
  temp
  fix
```

- Use kebab-case, all lowercase
- Keep it short but descriptive (2-4 words)
- Include ticket ID if the team uses one: `feat/PROJ-123-user-auth`

## Commit Messages

Follow Conventional Commits format:

```
<type>(<scope>): <subject>

[optional body]

[optional footer]
```

### Types

| Type | Purpose |
|------|---------|
| `feat` | New feature |
| `fix` | Bug fix |
| `refactor` | Code change that neither fixes nor adds |
| `docs` | Documentation only |
| `test` | Adding or correcting tests |
| `chore` | Build, CI, dependencies |
| `perf` | Performance improvement |
| `style` | Formatting, semicolons, etc. |
| `ci` | CI configuration |

### Rules

- Subject line: imperative mood, no period, max 72 chars
- Scope: optional, identifies the module/component
- Body: explain **why**, not **what** (the diff shows what)
- Footer: `BREAKING CHANGE:` for breaking changes, `Closes #123` for issues

```
Good:
  feat(auth): add JWT refresh token rotation
  fix(api): handle null response from payment gateway
  refactor(user): extract validation into shared module

  feat(search): add full-text search for documents

  Implement Elasticsearch integration for document search.
  This replaces the previous LIKE query approach which didn't
  scale beyond 10k documents.

  Closes #234

Bad:
  fixed stuff
  WIP
  update code
  feat: Add JWT refresh token rotation.  ← period, capitalized
```

## Pull Request Workflow

### PR Title

Same format as commit message subject:

```
feat(auth): add JWT refresh token rotation
```

### PR Description

```markdown
## Summary
Brief description of what this PR does and why.

## Changes
- Added refresh token rotation logic
- Updated auth middleware to check token expiry
- Added migration for refresh_tokens table

## Test Plan
- [ ] Unit tests pass
- [ ] Manual test: login → wait for token expiry → verify auto-refresh
- [ ] Manual test: revoked token → verify rejection
```

### PR Size

- Aim for **under 400 lines changed** per PR
- If larger, split into stacked PRs or feature-flag behind incremental merges
- One PR = one logical change (don't mix refactoring with features)

### Review Etiquette

- Self-review before requesting others
- Respond to all comments before merging
- Use "Request Changes" sparingly — prefer "Approve with suggestions"
- Resolve your own comments after addressing feedback

## Merge Strategies

| Strategy | When to Use |
|----------|-------------|
| **Squash merge** | Feature branches → main (default) |
| **Merge commit** | Release branches, long-lived branches |
| **Rebase** | Keeping linear history on personal branches |
| **Fast-forward** | Small, single-commit PRs |

- Default to **squash merge** for feature branches into main
- Squash message should be the PR title (conventional commit format)
- NEVER force-push to shared branches (main, develop, release/*)
- Rebase personal branches onto main before PR, not after

## Git Hygiene

- Delete branches after merge (enable auto-delete in GitHub settings)
- Don't commit generated files (build output, node_modules, .env)
- Use `.gitignore` templates for your tech stack
- Tag releases with semantic versioning: `v1.2.3`
- Sign commits when required by team policy

## Conflict Resolution

1. Pull latest main: `git fetch origin main`
2. Rebase onto main: `git rebase origin/main`
3. Resolve conflicts file by file
4. Test after resolution
5. Force-push to your branch (not shared branches): `git push --force-with-lease`

- Use `--force-with-lease` instead of `--force` to prevent overwriting others' pushes
- If rebase is complex (>5 conflicts), consider merge instead

## Recommended Scope

- **Scope**: Global (consistent across all projects)
- **Install**: `npx skills add skingford/skills --skill git-workflow -g -y`
