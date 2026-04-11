# Skills

A curated collection of Claude Code skills for practical development workflows. Each skill is individually installable via [`npx skills`](https://www.npmjs.com/package/skills).

## Quick Start

```bash
# Browse all available skills
npx skills add kingford/skills --list

# Install a single skill globally
npx skills add kingford/skills --skill go-pro -g -y

# Install a single skill to current project
npx skills add kingford/skills --skill api-design -y

# Install all skills globally
npx skills add kingford/skills --skill '*' -g -y
```

## Available Skills

| Skill | Description | Scope |
|-------|-------------|-------|
| [go-pro](./go-pro) | Go best practices — project structure, error handling, concurrency, testing | Global / Project |
| [api-design](./api-design) | RESTful & gRPC API design — naming, versioning, errors, pagination | Global / Project |
| [prompt-engineer](./prompt-engineer) | Prompt engineering — system prompts, few-shot, CoT, evaluation | Global |
| [mcp-ops](./mcp-ops) | MCP server development — tool design, resources, error handling | Global |
| [git-workflow](./git-workflow) | Git conventions — branch naming, commits, PRs, merge strategies | Global |
| [git-clean-main](./git-clean-main) | Keep AI files on dev, exclude from main/master | Global |
| [project-bootstrap](./project-bootstrap) | Portable skills — auto-restore on new machine via hook + lock file | Global |

## Portable Skills (New Machine Support)

Skills follow you across machines. Two mechanisms:

### Global Skills — One-Command Install

```bash
# On a new machine, install your full toolkit:
npx skills add kingford/skills --skill '*' -g -y

# Or via script:
curl -fsSL https://raw.githubusercontent.com/kingford/skills/main/scripts/install.sh | bash
```

### Project Skills — Auto-Restore from Lock File

Project-level skills are tracked in `skills-lock.json`. Add an auto-install hook so skills restore on clone:

**1. Install skills to project (creates `skills-lock.json`):**

```bash
npx skills add kingford/skills --skill go-pro -y
npx skills add kingford/skills --skill api-design -y
```

**2. Add auto-restore hook to `.claude/settings.json`:**

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [
          {
            "type": "command",
            "command": "test -f skills-lock.json && npx skills experimental_install",
            "timeout": 60,
            "statusMessage": "Syncing project skills..."
          }
        ]
      }
    ]
  }
}
```

**3. Commit both files:**

```bash
git add skills-lock.json .claude/settings.json
git commit -m "chore: add project skills with auto-restore"
```

Now on any new machine:

```bash
git clone <your-project>
cd <your-project>
claude   # Hook fires → skills auto-installed
```

## Creating a New Skill

1. Copy the [template](./template) folder
2. Rename the folder to your skill name (kebab-case)
3. Edit `SKILL.md` — update frontmatter and content
4. Submit a PR

See [template/SKILL.md](./template/SKILL.md) for the full structure.

## License

[MIT](./LICENSE)
