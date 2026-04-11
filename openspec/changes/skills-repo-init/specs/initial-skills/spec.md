## ADDED Requirements

### Requirement: Go best practices skill
The repo SHALL include a `go-pro/SKILL.md` skill that provides Go language best practices covering project structure, error handling, concurrency, testing, and performance.

#### Scenario: User writes Go code
- **WHEN** a user is working in a Go project with this skill installed
- **THEN** Claude applies Go idioms, standard project layout, and best practices from the skill

### Requirement: API design skill
The repo SHALL include a `api-design/SKILL.md` skill that provides RESTful and gRPC API design guidelines covering naming, versioning, error responses, pagination, and authentication patterns.

#### Scenario: User designs an API
- **WHEN** a user is creating or reviewing API endpoints with this skill installed
- **THEN** Claude follows the API design conventions defined in the skill

### Requirement: Prompt engineering skill
The repo SHALL include a `prompt-engineer/SKILL.md` skill that provides prompt writing methodology covering system prompt structure, few-shot examples, chain-of-thought, and evaluation techniques.

#### Scenario: User writes prompts
- **WHEN** a user is crafting LLM prompts with this skill installed
- **THEN** Claude applies structured prompt engineering techniques from the skill

### Requirement: MCP operations skill
The repo SHALL include a `mcp-ops/SKILL.md` skill that provides MCP server development best practices covering tool design, resource management, error handling, and testing.

#### Scenario: User builds MCP server
- **WHEN** a user is developing an MCP server with this skill installed
- **THEN** Claude follows MCP development patterns from the skill

### Requirement: Git workflow skill
The repo SHALL include a `git-workflow/SKILL.md` skill that provides git workflow conventions covering branch naming, commit messages, PR templates, and merge strategies.

#### Scenario: User manages git workflow
- **WHEN** a user is working with git in a project with this skill installed
- **THEN** Claude follows the git workflow conventions defined in the skill

### Requirement: Each skill has correct SKILL.md frontmatter
Every skill SKILL.md SHALL include valid YAML frontmatter with `name` (matching folder name, kebab-case) and `description` (clear trigger description for when Claude should use this skill).

#### Scenario: CLI can parse skill metadata
- **WHEN** `npx skills add skingford/skills --list` is run
- **THEN** each skill shows its name and description correctly
