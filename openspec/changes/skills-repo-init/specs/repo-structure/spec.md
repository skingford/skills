## ADDED Requirements

### Requirement: Flat skill folder structure
The repo SHALL use a flat folder structure where each skill is a top-level directory containing at minimum a `SKILL.md` file.

#### Scenario: Skill discovery by CLI
- **WHEN** a user runs `npx skills add kingford/skills --list`
- **THEN** all skills are listed with their names and descriptions extracted from `SKILL.md` frontmatter

#### Scenario: Single skill install
- **WHEN** a user runs `npx skills add kingford/skills --skill go-pro`
- **THEN** only the `go-pro` skill is installed to the target agent directory

### Requirement: README as skill catalog
The repo SHALL include a `README.md` at the root that lists all available skills with their names, descriptions, and recommended scope (global vs project-level).

#### Scenario: User browses the repo
- **WHEN** a user visits the GitHub repo page
- **THEN** they see a table of all skills with install commands, descriptions, and scope recommendations

### Requirement: Standard repo files
The repo SHALL include a `LICENSE` (MIT) and `.gitignore` file at the root.

#### Scenario: Open-source compliance
- **WHEN** a user or organization evaluates the repo for use
- **THEN** they find a clear MIT license permitting unrestricted use

### Requirement: Compatible with skills-lock.json
Project-level installs SHALL be automatically tracked in `skills-lock.json` by the `npx skills` CLI without any custom tooling.

#### Scenario: Reproducible project-level install
- **WHEN** a user runs `npx skills add kingford/skills --skill go-pro` (without `-g`)
- **THEN** a `skills-lock.json` entry is created with `source: "kingford/skills"` and a `computedHash`
- **AND** another user can run `npx skills experimental_install` to restore the same skill
