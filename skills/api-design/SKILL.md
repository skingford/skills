---
name: api-design
description: "RESTful and gRPC API design guidelines. Use when designing, reviewing, or implementing API endpoints. Covers URL naming, versioning, error responses, pagination, authentication patterns, and request/response conventions. Triggers on tasks involving API routes, endpoint design, OpenAPI specs, or protobuf definitions."
---

# API Design

Opinionated API design guidelines for building consistent, predictable, and developer-friendly APIs.

## When to Use

Use this skill when:

- Designing new API endpoints (REST or gRPC)
- Reviewing existing API design for consistency
- Writing OpenAPI/Swagger specs or protobuf definitions
- Implementing error handling for APIs
- Setting up pagination, filtering, or sorting

Do NOT use this skill when:

- Building internal function interfaces (not network APIs)
- Working on frontend-only code

## URL Design (REST)

- Use nouns, not verbs: `/users`, not `/getUsers`
- Use plural nouns: `/users`, `/orders`, not `/user`, `/order`
- Use kebab-case for multi-word resources: `/user-profiles`, not `/userProfiles`
- Nest for relationships: `/users/{id}/orders` (max 2 levels deep)
- Use query params for filtering, not URL segments: `/users?role=admin`

```
Good:
GET    /api/v1/users
GET    /api/v1/users/{id}
POST   /api/v1/users
PUT    /api/v1/users/{id}
DELETE /api/v1/users/{id}
GET    /api/v1/users/{id}/orders

Bad:
GET    /api/v1/getUser/{id}
POST   /api/v1/createUser
GET    /api/v1/users/{id}/orders/{orderId}/items/{itemId}/details  # Too deep
```

## HTTP Methods

| Method | Purpose | Idempotent | Request Body |
|--------|---------|------------|--------------|
| GET    | Read resource(s) | Yes | No |
| POST   | Create resource | No | Yes |
| PUT    | Full replace | Yes | Yes |
| PATCH  | Partial update | No | Yes |
| DELETE | Remove resource | Yes | No |

- POST returns `201 Created` with the created resource and `Location` header
- PUT/PATCH returns `200 OK` with the updated resource
- DELETE returns `204 No Content`
- GET collection returns `200 OK` with array (empty array if no results, not 404)

## Versioning

- Use URL path versioning: `/api/v1/users`
- NEVER break existing versions — add new fields, don't remove or rename
- Deprecate with `Sunset` header and migration docs before removal
- Major version bump only for breaking changes

## Error Responses

Use a consistent error format across all endpoints:

```json
{
  "error": {
    "code": "VALIDATION_FAILED",
    "message": "The request body is invalid",
    "details": [
      {
        "field": "email",
        "reason": "must be a valid email address"
      }
    ],
    "request_id": "req_abc123"
  }
}
```

- ALWAYS include a machine-readable `code` (uppercase snake_case)
- ALWAYS include a human-readable `message`
- Include `details` array for validation errors
- Include `request_id` for traceability
- Use appropriate HTTP status codes:

| Status | Use Case |
|--------|----------|
| 400 | Validation error, malformed request |
| 401 | Missing or invalid authentication |
| 403 | Authenticated but not authorized |
| 404 | Resource not found |
| 409 | Conflict (duplicate, state conflict) |
| 422 | Semantically invalid (business rule violation) |
| 429 | Rate limited |
| 500 | Unexpected server error |

## Pagination

Use cursor-based pagination for large or frequently-updated datasets. Offset-based is acceptable for small, stable datasets.

```json
// Request
GET /api/v1/users?limit=20&cursor=eyJpZCI6MTAwfQ

// Response
{
  "data": [...],
  "pagination": {
    "next_cursor": "eyJpZCI6MTIwfQ",
    "has_more": true
  }
}
```

- Default `limit` to a reasonable number (20-50)
- Cap `limit` to a maximum (100-200)
- Return `has_more` boolean so clients know if there are more pages
- NEVER return total count in paginated responses (it's expensive at scale)

## Authentication

- Use `Authorization: Bearer <token>` header for API tokens
- Use short-lived JWTs (15-30 min) with refresh tokens for user sessions
- API keys go in headers (`X-API-Key`), NEVER in URLs
- Return `401` for missing/expired auth, `403` for insufficient permissions
- Rate limit by API key or user ID, not by IP alone

## Request/Response Conventions

- Use `snake_case` for JSON field names
- Use ISO 8601 for dates: `"2024-01-15T08:30:00Z"`
- Use milliseconds for timestamps when precision matters
- Wrap collection responses in `{ "data": [...] }` for extensibility
- Include `created_at` and `updated_at` in all resources
- Use UUID v4 or ULID for public IDs — never expose auto-increment IDs

## gRPC Specifics

- Use `PascalCase` for service and message names
- Use `snake_case` for field names in proto definitions
- Define standard error details with `google.rpc.Status`
- Use `FieldMask` for partial updates
- Stream only when the data naturally flows (logs, events, chat)

## Recommended Scope

- **Scope**: Both
- **Global**: `npx skills add kingford/skills --skill api-design -g -y`
- **Project**: `npx skills add kingford/skills --skill api-design -y`
