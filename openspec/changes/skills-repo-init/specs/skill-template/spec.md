## ADDED Requirements

### Requirement: Template skill exists
The repo SHALL include a `template/SKILL.md` file that serves as a scaffold for creating new skills.

#### Scenario: User creates a new skill
- **WHEN** a developer wants to add a new skill to the repo
- **THEN** they can copy the `template/` folder, rename it, and fill in the placeholders

### Requirement: Template includes all standard sections
The template SKILL.md SHALL include the following sections with placeholder content:
- YAML frontmatter (`name`, `description`)
- Overview / purpose
- When to use / when not to use
- Guidelines / best practices
- Examples
- Recommended scope (global vs project)

#### Scenario: Template completeness
- **WHEN** a developer copies the template and fills in all placeholders
- **THEN** the resulting skill follows the same structure as the repo's existing skills
