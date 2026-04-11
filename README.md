[English](./README.md) | [中文](./README_zh.md)

# Skills

A curated collection of Claude Code skills for practical development workflows. Each skill is individually installable via [`npx skills`](https://www.npmjs.com/package/skills).

## Quick Start

```bash
# Browse all available skills
npx skills add skingford/skills --list

# Install a single skill globally
npx skills add skingford/skills --skill go-pro -g -y

# Install a single skill to current project
npx skills add skingford/skills --skill api-design -y

# Install all skills globally
npx skills add skingford/skills --skill '*' -g -y
```

## Available Skills

| Skill | Description | Scope | Agents |
|-------|-------------|-------|--------|
| **Coding** | | | |
| [go-pro](./skills/go-pro) | Go best practices — project structure, error handling, concurrency, testing | Global / Project | Claude, Codex, Cursor |
| [api-design](./skills/api-design) | RESTful & gRPC API design — naming, versioning, errors, pagination | Global / Project | Claude, Codex, Cursor |
| **AI** | | | |
| [prompt-engineer](./skills/prompt-engineer) | Prompt engineering — system prompts, few-shot, CoT, evaluation | Global | Claude, Codex, Cursor |
| [mcp-ops](./skills/mcp-ops) | MCP server development — tool design, resources, error handling | Global | Claude, Codex, Cursor |
| **Git & Workflow** | | | |
| [git-workflow](./skills/git-workflow) | Git conventions — branch naming, commits, PRs, merge strategies | Global | Claude, Codex, Cursor |
| [git-clean-main](./skills/git-clean-main) | Keep AI files on dev, exclude from main/master | Global | Claude, Codex, Cursor |
| [project-bootstrap](./skills/project-bootstrap) | Portable skills — auto-restore on new machine via hook + lock file | Global | Claude |

## Multi-Agent Support

Skills declare which AI coding agents they support via the `agents` field in SKILL.md frontmatter:

```yaml
---
name: my-skill
description: "..."
agents: [claude, codex, cursor]
---
```

| Agent | Identifier | Install Directory | Format |
|-------|------------|-------------------|--------|
| Claude Code | `claude` | `.claude/skills/` | SKILL.md |
| Codex CLI | `codex` | `.codex/skills/` | SKILL.md |
| Cursor | `cursor` | `.cursor/rules/` | .mdc |

Most skills are agent-agnostic and work with all three. Skills that depend on agent-specific features (e.g., Claude hooks) list only compatible agents.

## Portable Skills (New Machine Support)

Skills follow you across machines. Two mechanisms:

### Global Skills — One-Command Install

```bash
# On a new machine, install your full toolkit:
npx skills add skingford/skills --skill '*' -g -y

# Or via script:
curl -fsSL https://raw.githubusercontent.com/skingford/skills/main/scripts/install.sh | bash
```

### Project Skills — Auto-Restore from Lock File

Project-level skills are tracked in `skills-lock.json`. Add an auto-install hook so skills restore on clone:

**1. Install skills to project (creates `skills-lock.json`):**

```bash
npx skills add skingford/skills --skill go-pro -y
npx skills add skingford/skills --skill api-design -y
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

1. Copy the [template](./skills/template) folder
2. Rename the folder to your skill name (kebab-case)
3. Edit `SKILL.md` — update frontmatter (`name`, `description`, `agents`) and content
4. Set `agents` to the list of supported agents (e.g., `[claude, codex, cursor]`)
5. Submit a PR

See [skills/template/SKILL.md](./skills/template/SKILL.md) for the full structure.

## License

[MIT](./LICENSE)
