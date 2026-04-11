---
name: project-bootstrap
description: "Make project skills portable across machines. Use when setting up a new project with skills, onboarding a new machine, or ensuring skills-lock.json and auto-install hooks are configured. Triggers when user mentions project setup, new machine, portable skills, or restoring skills."
---

# Project Bootstrap

Ensure project-level skills survive across machines — clone and go.

## When to Use

Use this skill when:

- Setting up a new project that uses skills
- Cloning an existing project on a new machine
- User asks about making skills portable or persistent
- User mentions "new machine", "restore skills", or "project setup"

Do NOT use this skill when:

- Installing global skills (use `npx skills add ... -g`)
- Working within a project that's already bootstrapped

## How It Works

Two mechanisms work together to make skills portable:

```
┌──────────────────────────────────────────────────────────┐
│                   Project Repo (Git)                     │
│                                                          │
│  skills-lock.json          ← Tracks installed skills     │
│  .claude/settings.json     ← Auto-install hook           │
│                                                          │
│  On new machine:                                         │
│  1. git clone ...                                        │
│  2. Open in Claude Code                                  │
│  3. SessionStart hook fires                              │
│  4. Detects skills-lock.json                             │
│  5. Runs npx skills experimental_install                 │
│  6. All project skills restored automatically            │
└──────────────────────────────────────────────────────────┘
```

## Setup: Auto-Install Hook

Add to `.claude/settings.json` in the project root:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup",
        "hooks": [
          {
            "type": "command",
            "command": "if [ -f skills-lock.json ]; then installed=$(npx skills list 2>/dev/null | grep -c 'Project Skills' || true); locked=$(python3 -c \"import json; print(len(json.load(open('skills-lock.json'))['skills']))\" 2>/dev/null || echo 0); if [ \"$installed\" -lt \"$locked\" ] 2>/dev/null || [ \"$installed\" = \"0\" ]; then npx skills experimental_install; fi; fi",
            "timeout": 120,
            "statusMessage": "Restoring project skills..."
          }
        ]
      }
    ]
  }
}
```

This hook:
- Fires on Claude Code session startup
- Checks if `skills-lock.json` exists
- Compares installed vs locked skill count
- Only runs install if skills are missing
- Timeout after 120s to avoid hanging

### Simplified Version

If you prefer a simpler (always-run) version:

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

## Setup: skills-lock.json

When you install project-level skills, `skills-lock.json` is auto-generated:

```bash
# Install skills to project (NOT global, no -g flag)
npx skills add skingford/skills --skill go-pro -y
npx skills add skingford/skills --skill api-design -y
npx skills add antfu/skills --skill vite -y
```

This creates `skills-lock.json`:

```json
{
  "version": 1,
  "skills": {
    "go-pro": {
      "source": "skingford/skills",
      "sourceType": "github",
      "computedHash": "abc123..."
    },
    "api-design": {
      "source": "skingford/skills",
      "sourceType": "github",
      "computedHash": "def456..."
    },
    "vite": {
      "source": "antfu/skills",
      "sourceType": "github",
      "computedHash": "ghi789..."
    }
  }
}
```

**Commit this file to git.** It's the key to portability.

## Full Bootstrap Checklist

When setting up a project for portable skills:

```bash
# 1. Install desired skills at project level
npx skills add skingford/skills --skill go-pro -y
npx skills add skingford/skills --skill api-design -y

# 2. Verify skills-lock.json was created
cat skills-lock.json

# 3. Add auto-install hook to .claude/settings.json
# (see Setup section above)

# 4. Commit both files
git add skills-lock.json .claude/settings.json
git commit -m "chore: add project skills with auto-restore"
```

## New Machine Workflow

On a fresh machine after cloning:

```bash
# Option A: Automatic (if hook is configured)
git clone <repo>
cd <repo>
claude    # SessionStart hook auto-installs skills

# Option B: Manual
git clone <repo>
cd <repo>
npx skills experimental_install
```

## Global Skills on New Machine

For global skills (your personal toolkit), run once on the new machine:

```bash
# Install all global skills from the repo
npx skills add skingford/skills --skill '*' -g -y

# Or use the install script
curl -fsSL https://raw.githubusercontent.com/skingford/skills/main/scripts/install.sh | bash
```

## Recommended Scope

- **Scope**: Global (useful for any project you set up)
- **Install**: `npx skills add skingford/skills --skill project-bootstrap -g -y`
