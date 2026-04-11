## Context

The `skingford/skills` repo is currently empty (just a README). The goal is to turn it into a public skills monorepo compatible with the `npx skills` CLI ecosystem (agentskills.io). The CLI discovers skills by scanning for `SKILL.md` files in a Git repo, so the design is constrained by that convention.

Reference repos: `anthropics/skills` (17 skills), `antfu/skills` (17 skills), `vercel-labs/agent-skills` (7 skills).

## Goals / Non-Goals

**Goals:**
- Flat, discoverable repo structure — each skill is a top-level folder with `SKILL.md`
- Compatible with `npx skills add/list/find` for both global and project-level installs
- `skills-lock.json` support works automatically (project-level installs track it)
- First batch of 5 practical skills that reflect real workflow needs
- Template skill for easy creation of new skills
- Clear README as both documentation and skill catalog

**Non-Goals:**
- No custom CLI tooling — rely entirely on `npx skills`
- No build step or compilation — skills are plain Markdown
- No CI/CD pipeline (can be added later)
- No plugin/marketplace registration (manual for now)
- No skill dependencies or inter-skill references

## Decisions

### 1. Flat folder structure (not categorized)

All skill folders live at the repo root, not nested under categories like `coding/go-pro/`.

**Why**: The `npx skills add --list` output is cleaner with flat structure. Categories can be documented in README instead. All reference repos (anthropics, antfu, vercel-labs) use flat structure. The CLI `--skill` flag references the folder name directly.

**Alternative considered**: Grouped by category (`coding/`, `workflow/`, `tools/`). Rejected because it complicates install commands and the CLI doesn't render group names.

### 2. SKILL.md frontmatter — only `name` and `description`

Each `SKILL.md` uses minimal frontmatter:
```yaml
---
name: skill-name
description: When to trigger and what it does
---
```

**Why**: This is the standard contract. The `name` is the install identifier, the `description` is what the CLI shows and what Claude uses to decide when to trigger the skill. No additional metadata needed.

### 3. Recommended scope as documentation, not enforcement

Each skill's SKILL.md content documents whether it's recommended for global or project-level install, but this is advisory only.

**Why**: The CLI doesn't have a mechanism to enforce scope. Users decide via `-g` flag. Documenting the recommendation in the skill itself is the pragmatic approach.

### 4. MIT License

**Why**: Maximum permissiveness for a public skills repo. Anthropic's repo uses Apache 2.0 for open skills, but MIT is simpler and equally permissive for Markdown-only content.

### 5. Skill content strategy — actionable guidelines, not reference docs

Each skill provides:
- Clear trigger description (when Claude should activate)
- Opinionated best practices (not exhaustive reference)
- Code examples and anti-patterns
- Checklist-style guidelines

**Why**: Skills work best as concise, opinionated instructions. Claude already has broad knowledge — skills should sharpen and focus it, not repeat documentation.

## Risks / Trade-offs

- **[Discoverability]** Skills won't appear in `npx skills find` until someone installs from this repo and usage data reaches skills.sh → Mitigation: Share repo link directly, add to README of other projects
- **[Staleness]** Best practices evolve — skills may become outdated → Mitigation: Keep skills small and focused; version via git tags
- **[Scope creep]** Temptation to add too many skills → Mitigation: Start with 5, add only when a real workflow need is identified
