---
name: my-skill-name
description: "Replace with a clear description of what this skill does and when Claude should trigger it. Be specific about trigger conditions."
agents: [claude, codex, cursor]
---

# My Skill Name

<!-- Brief overview: what does this skill help with? -->

## When to Use

Use this skill when:

- <!-- Trigger condition 1 -->
- <!-- Trigger condition 2 -->
- <!-- Trigger condition 3 -->

Do NOT use this skill when:

- <!-- Exclusion 1 -->
- <!-- Exclusion 2 -->

## Guidelines

<!-- Core best practices and rules Claude should follow -->

### <!-- Category 1 -->

- <!-- Guideline -->
- <!-- Guideline -->

### <!-- Category 2 -->

- <!-- Guideline -->
- <!-- Guideline -->

## Examples

### Good

```
<!-- Example of correct usage -->
```

### Bad

```
<!-- Example of what to avoid -->
```

## Agent Compatibility

- **Agents**: Claude Code, Codex CLI, Cursor
- Remove any agent from the `agents` frontmatter list if this skill depends on agent-specific features (e.g., Claude hooks, Cursor-specific rules)

## Recommended Scope

<!-- One of: Global (install with -g), Project-level, or Both -->
- **Scope**: Global
- **Install**: `npx skills add skingford/skills --skill my-skill-name -g -y`
