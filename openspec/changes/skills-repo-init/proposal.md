## Why

We need a centralized, public GitHub repo (`skingford/skills`) to host curated Claude Code skills that can be individually installed via `npx skills add skingford/skills --skill <name>`. Currently skills are scattered across `~/.agents/skills/` as symlinks from various sources, with no version control, no reproducibility (no lock file), and no way to share with others.

## What Changes

- Initialize the repo structure as a standard skills monorepo compatible with `npx skills` CLI
- Add a `template/` skill as a scaffold for creating new skills
- Create a first batch of practical skills: `go-pro`, `api-design`, `prompt-engineer`, `mcp-ops`, `git-workflow`
- Provide a comprehensive README with skill catalog, install instructions, and contribution guide
- Add LICENSE (MIT) for open-source distribution
- Support both global (`-g`) and project-level installation, with `skills-lock.json` auto-tracked for project-level installs

## Capabilities

### New Capabilities
- `repo-structure`: Standard skills monorepo layout — flat folder structure, each skill is a folder with `SKILL.md`, compatible with `npx skills add/list/find`
- `skill-template`: Reusable template for scaffolding new skills with correct frontmatter and section structure
- `initial-skills`: First batch of 5 practical skills covering Go, API design, prompt engineering, MCP operations, and git workflow

### Modified Capabilities
<!-- None — this is a greenfield repo -->

## Impact

- **Repository**: Complete restructure of the currently empty `skills` repo
- **Files created**: ~10 new files (README, LICENSE, 5 SKILL.md files, template SKILL.md, .gitignore)
- **Dependencies**: None — skills are plain Markdown, no runtime dependencies
- **Distribution**: Published via GitHub, discoverable via `npx skills find` after first install
