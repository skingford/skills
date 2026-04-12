[English](./README.md) | [中文](./README_zh.md)

# Skills

精选的 Claude Code 技能集合，用于实用的开发工作流。每个技能均可通过 [`npx skills`](https://www.npmjs.com/package/skills) 单独安装。

## 快速开始

```bash
# 交互式安装 — 选择 Agent 和技能
curl -fsSL https://raw.githubusercontent.com/skingford/skills/main/scripts/install.sh | bash
```

<details>
<summary>手动安装命令</summary>

```bash
# 浏览所有可用技能
npx skills add skingford/skills --list

# 全局安装单个技能
npx skills add skingford/skills --skill go-pro -g -y

# 安装单个技能到当前项目
npx skills add skingford/skills --skill api-design -y

# 全局安装所有技能
npx skills add skingford/skills --skill '*' -g -y

# 指定安装到某个 Agent
npx skills add skingford/skills --skill go-pro -g -y --agent claude-code
npx skills add skingford/skills --skill go-pro -g -y --agent codex
npx skills add skingford/skills --skill go-pro -g -y --agent cursor

# 安装所有技能到所有 Agent
npx skills add skingford/skills --all -g
```

</details>

## 可用技能

| 技能 | 说明 | 作用域 | 支持的 Agent |
|------|------|--------|-------------|
| **编程** | | | |
| [go-pro](./skills/go-pro) | Go 最佳实践 — 项目结构、错误处理、并发、测试 | 全局 / 项目 | Claude, Codex, Cursor |
| [api-design](./skills/api-design) | RESTful & gRPC API 设计 — 命名、版本控制、错误处理、分页 | 全局 / 项目 | Claude, Codex, Cursor |
| **AI** | | | |
| [prompt-engineer](./skills/prompt-engineer) | 提示工程 — 系统提示词、少样本、思维链、评估 | 全局 | Claude, Codex, Cursor |
| [mcp-ops](./skills/mcp-ops) | MCP 服务器开发 — 工具设计、资源管理、错误处理 | 全局 | Claude, Codex, Cursor |
| **Git & 工作流** | | | |
| [git-workflow](./skills/git-workflow) | Git 规范 — 分支命名、提交、PR、合并策略 | 全局 | Claude, Codex, Cursor |
| [git-clean-main](./skills/git-clean-main) | 将 AI 文件保留在 dev 分支，排除出 main/master | 全局 | Claude, Codex, Cursor |
| [project-bootstrap](./skills/project-bootstrap) | 便携技能 — 通过 hook + lock 文件在新机器上自动恢复 | 全局 | Claude |

## 多 Agent 支持

技能通过 SKILL.md frontmatter 中的 `agents` 字段声明支持哪些 AI 编程 Agent：

```yaml
---
name: my-skill
description: "..."
agents: [claude-code, codex, cursor]
---
```

**常用 Agent：**

| Agent | `--agent` 标识符 | 安装目录 |
|-------|-----------------|----------|
| Claude Code | `claude-code` | `.claude/skills/` |
| OpenAI Codex CLI | `codex` | `.agents/skills/` |
| Cursor | `cursor` | `.cursor/rules/` |
| Windsurf | `windsurf` | `.windsurf/rules/` |
| Augment | `augment` | `.augment/skills/` |
| Cline | `cline` | `.cline/rules/` |
| Roo | `roo` | `.roo/rules/` |
| Trae | `trae` | `.trae/rules/` |
| Kiro | `kiro-cli` | `.kiro/skills/` |
| Gemini CLI | `gemini-cli` | `.gemini/skills/` |
| GitHub Copilot | `github-copilot` | `.github/copilot/skills/` |
| Junie | `junie` | `.junie/skills/` |

<details>
<summary>所有支持的 Agent</summary>

`amp` `antigravity` `augment` `bob` `claude-code` `openclaw` `cline` `codebuddy` `codex` `command-code` `continue` `cortex` `crush` `cursor` `deepagents` `droid` `firebender` `gemini-cli` `github-copilot` `goose` `junie` `iflow-cli` `kilo` `kimi-cli` `kiro-cli` `kode` `mcpjam` `mistral-vibe` `mux` `opencode` `openhands` `pi` `qoder` `qwen-code` `replit` `roo` `trae` `trae-cn` `warp` `windsurf` `zencoder` `neovate` `pochi` `adal` `universal`

</details>

**指定 Agent 安装：**

```bash
# 仅安装到 Claude Code
npx skills add skingford/skills --skill go-pro -g -y --agent claude-code

# 仅安装到 Codex CLI
npx skills add skingford/skills --skill go-pro -g -y --agent codex

# 仅安装到 Cursor
npx skills add skingford/skills --skill go-pro -g -y --agent cursor

# 安装到多个 Agent
npx skills add skingford/skills --skill go-pro -g -y --agent claude-code codex

# 安装到所有 Agent（默认行为）
npx skills add skingford/skills --skill go-pro -g -y --agent '*'
```

大多数技能与 Agent 无关，可跨 Agent 使用。依赖特定 Agent 功能（如 Claude hooks）的技能仅列出兼容的 Agent。

## 便携技能（新机器支持）

技能可以跟随你跨机器使用。有两种机制：

### 全局技能 — 一条命令安装

```bash
# 在新机器上安装你的全部工具集：
npx skills add skingford/skills --skill '*' -g -y

# 或通过脚本安装：
curl -fsSL https://raw.githubusercontent.com/skingford/skills/main/scripts/install.sh | bash
```

### 项目技能 — 从 Lock 文件自动恢复

项目级技能通过 `skills-lock.json` 跟踪。添加自动安装 hook，技能会在 clone 后自动恢复：

**1. 安装技能到项目（创建 `skills-lock.json`）：**

```bash
npx skills add skingford/skills --skill go-pro -y
npx skills add skingford/skills --skill api-design -y
```

**2. 在 `.claude/settings.json` 中添加自动恢复 hook：**

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

**3. 提交这两个文件：**

```bash
git add skills-lock.json .claude/settings.json
git commit -m "chore: add project skills with auto-restore"
```

现在在任何新机器上：

```bash
git clone <your-project>
cd <your-project>
claude   # Hook 触发 → 技能自动安装
```

## 创建新技能

1. 复制 [template](./skills/template) 文件夹
2. 将文件夹重命名为你的技能名称（kebab-case）
3. 编辑 `SKILL.md` — 更新 frontmatter（`name`、`description`、`agents`）和内容
4. 将 `agents` 设置为支持的 Agent 列表（如 `[claude-code, codex, cursor]`）
5. 提交 PR

完整结构请参见 [skills/template/SKILL.md](./skills/template/SKILL.md)。

## 许可证

[MIT](./LICENSE)
