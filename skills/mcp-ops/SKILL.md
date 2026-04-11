---
name: mcp-ops
description: "MCP (Model Context Protocol) server development best practices. Use when building, debugging, or reviewing MCP servers and tools. Covers tool design, resource management, error handling, transport configuration, and testing. Triggers on tasks involving MCP server code, tool definitions, or MCP integration."
---

# MCP Ops

Best practices for building robust MCP servers that LLMs can use effectively.

## When to Use

Use this skill when:

- Building a new MCP server (Python/FastMCP or TypeScript/MCP SDK)
- Designing MCP tools, resources, or prompts
- Debugging MCP server connectivity or tool execution
- Reviewing MCP server code for quality
- Integrating MCP servers with Claude Code or other clients

Do NOT use this skill when:

- Using existing MCP tools (just call them)
- Working on non-MCP server code

## Tool Design Principles

### Name Tools Clearly

```python
# Good — verb-noun, descriptive
@mcp.tool()
def search_documents(query: str, limit: int = 10) -> list[dict]:
    """Search documents by keyword and return matching results."""

# Bad — vague, ambiguous
@mcp.tool()
def process(data: str) -> str:
    """Process the data."""
```

### Write Descriptions for the LLM

Tool descriptions are the LLM's primary guide for when and how to use the tool. Write them for the model, not for developers.

```python
# Good — tells the LLM when to use, what it returns, and edge cases
@mcp.tool()
def get_user_profile(user_id: str) -> dict:
    """Fetch a user's profile by their unique ID.

    Returns the user's name, email, role, and creation date.
    Returns an error if the user ID doesn't exist.
    Use this when you need user details — don't guess user info."""

# Bad — too terse, LLM doesn't know when to use it
@mcp.tool()
def get_user(id: str) -> dict:
    """Gets a user."""
```

### Parameter Design

- Use descriptive parameter names, not abbreviations
- Add type hints and default values
- Document each parameter's purpose and constraints
- Keep required parameters minimal — use defaults for optional ones

```python
@mcp.tool()
def search_logs(
    query: str,
    service: str = "all",
    level: str = "info",
    limit: int = 50,
    since_hours: int = 24,
) -> list[dict]:
    """Search application logs across services.

    Args:
        query: Text to search for in log messages (supports regex)
        service: Service name to filter by, or "all" for all services
        level: Minimum log level: debug, info, warn, error
        limit: Maximum number of results (1-500, default 50)
        since_hours: How far back to search in hours (default 24)
    """
```

### Return Structured Data

```python
# Good — structured, predictable
@mcp.tool()
def check_deployment_status(env: str) -> dict:
    return {
        "environment": env,
        "status": "healthy",
        "version": "v2.3.1",
        "last_deployed": "2024-01-15T08:30:00Z",
        "instances": 3,
    }

# Bad — unstructured string
@mcp.tool()
def check_deployment_status(env: str) -> str:
    return f"Deployment to {env} is healthy, running v2.3.1"
```

## Error Handling

- Return descriptive error messages that help the LLM recover
- Distinguish between user errors (bad input) and system errors (service down)
- NEVER let exceptions propagate unhandled — catch and return meaningful errors

```python
@mcp.tool()
def delete_record(record_id: str) -> dict:
    try:
        record = db.find(record_id)
        if not record:
            return {"error": f"Record '{record_id}' not found. Use search_records to find valid IDs."}
        db.delete(record_id)
        return {"success": True, "deleted_id": record_id}
    except PermissionError:
        return {"error": f"Permission denied. The current user cannot delete record '{record_id}'."}
    except Exception as e:
        return {"error": f"Unexpected error deleting record: {str(e)}"}
```

## Resource Design

Resources are for data the LLM reads, not actions it takes. Use resources for:

- Configuration files
- Documentation
- Database schemas
- Status dashboards

```python
@mcp.resource("config://app")
def get_app_config() -> str:
    """Current application configuration."""
    return json.dumps(load_config(), indent=2)

@mcp.resource("schema://database")
def get_db_schema() -> str:
    """Database table definitions and relationships."""
    return generate_schema_doc()
```

## Server Structure (Python/FastMCP)

```python
from mcp.server.fastmcp import FastMCP

mcp = FastMCP(
    "my-server",
    description="Brief description of what this server provides",
)

# Group related tools logically
# --- User Management ---
@mcp.tool()
def create_user(...): ...

@mcp.tool()
def get_user(...): ...

# --- Data Operations ---
@mcp.tool()
def query_data(...): ...

if __name__ == "__main__":
    mcp.run()
```

## Server Structure (TypeScript/MCP SDK)

```typescript
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const server = new McpServer({
  name: "my-server",
  version: "1.0.0",
});

server.tool(
  "search_documents",
  "Search documents by keyword",
  { query: z.string(), limit: z.number().default(10) },
  async ({ query, limit }) => {
    const results = await search(query, limit);
    return { content: [{ type: "text", text: JSON.stringify(results) }] };
  }
);

const transport = new StdioServerTransport();
await server.connect(transport);
```

## Testing

- Test each tool independently with various inputs
- Test error paths (invalid input, missing resources, permission denied)
- Use `mcp dev` or `npx @anthropic-ai/mcp-inspector` for interactive testing
- Verify tool descriptions are clear by having someone (or an LLM) use them blind

```bash
# Interactive testing
npx @anthropic-ai/mcp-inspector python server.py

# Or with FastMCP dev mode
mcp dev server.py
```

## Configuration (claude_desktop_config.json)

```json
{
  "mcpServers": {
    "my-server": {
      "command": "python",
      "args": ["path/to/server.py"],
      "env": {
        "API_KEY": "your-key"
      }
    }
  }
}
```

- Keep secrets in `env`, never hardcode in server code
- Use absolute paths for `command` and `args`
- Test the exact command manually before adding to config

## Recommended Scope

- **Scope**: Global (useful whenever building MCP servers)
- **Install**: `npx skills add kingford/skills --skill mcp-ops -g -y`
