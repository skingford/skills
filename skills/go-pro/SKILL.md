---
name: go-pro
description: "Go language best practices and idiomatic patterns. Use when writing, reviewing, or refactoring Go code. Covers project structure, error handling, concurrency, testing, and performance. Triggers on tasks involving .go files, Go modules, or Go project setup."
agents: [claude, codex, cursor]
---

# Go Pro

Opinionated Go best practices for writing clean, idiomatic, production-ready Go code.

## When to Use

Use this skill when:

- Writing new Go code or packages
- Reviewing or refactoring existing Go code
- Setting up Go project structure
- Working with Go concurrency patterns
- Writing Go tests

Do NOT use this skill when:

- Working on non-Go code
- The user explicitly asks for a non-standard approach

## Project Structure

```
project/
├── cmd/
│   └── app/
│       └── main.go          # Entrypoints only — parse flags, wire deps, run
├── internal/                # Private application code
│   ├── domain/              # Business logic, no external dependencies
│   ├── handler/             # HTTP/gRPC handlers
│   ├── repository/          # Data access layer
│   └── service/             # Application services
├── pkg/                     # Public reusable libraries (use sparingly)
├── api/                     # API definitions (proto, OpenAPI)
├── go.mod
└── go.sum
```

- `cmd/` entrypoints SHALL be thin — only flag parsing, dependency wiring, and `run()`
- Business logic SHALL live in `internal/`, never in `cmd/`
- Use `internal/` over `pkg/` unless the package is explicitly designed for external consumption
- One package per concern — avoid "utils", "common", "helpers"

## Error Handling

- ALWAYS wrap errors with context: `fmt.Errorf("fetch user %d: %w", id, err)`
- NEVER use `panic()` in library code — return errors instead
- Define sentinel errors for expected failure cases: `var ErrNotFound = errors.New("not found")`
- Use `errors.Is()` and `errors.As()` for error checking, never string comparison
- Handle errors immediately — no `_ = doSomething()`

```go
// Good
user, err := repo.FindByID(ctx, id)
if err != nil {
    return fmt.Errorf("find user %d: %w", id, err)
}

// Bad
user, err := repo.FindByID(ctx, id)
if err != nil {
    return err // Lost context
}
```

## Concurrency

- ALWAYS pass `context.Context` as the first parameter
- Use `errgroup.Group` for parallel tasks that can fail
- NEVER start goroutines without a clear shutdown path
- Use channels for communication, mutexes for state protection
- Prefer `sync.Once` for lazy initialization
- Buffer channels only when you can justify the buffer size

```go
// Good — structured concurrency with errgroup
g, ctx := errgroup.WithContext(ctx)
g.Go(func() error {
    return fetchUsers(ctx)
})
g.Go(func() error {
    return fetchOrders(ctx)
})
if err := g.Wait(); err != nil {
    return fmt.Errorf("fetch data: %w", err)
}
```

## Interfaces

- Define interfaces at the **consumer** side, not the producer side
- Keep interfaces small — 1-3 methods maximum
- Accept interfaces, return structs
- Name single-method interfaces with `-er` suffix: `Reader`, `Storer`, `Notifier`

```go
// Good — consumer defines what it needs
type UserFinder interface {
    FindByID(ctx context.Context, id int64) (*User, error)
}

func NewHandler(finder UserFinder) *Handler { ... }
```

## Testing

- Use table-driven tests with `t.Run()` for subtests
- Test behavior, not implementation — test public API, not internals
- Use `testify/assert` or `testify/require` for assertions
- Use `t.Helper()` in test utility functions
- Use `t.Parallel()` for independent tests
- Name test cases descriptively: `"returns error when user not found"`

```go
func TestFindUser(t *testing.T) {
    tests := []struct {
        name    string
        id      int64
        want    *User
        wantErr error
    }{
        {
            name:    "returns user when found",
            id:      1,
            want:    &User{ID: 1, Name: "Alice"},
            wantErr: nil,
        },
        {
            name:    "returns error when not found",
            id:      999,
            want:    nil,
            wantErr: ErrNotFound,
        },
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            t.Parallel()
            got, err := repo.FindByID(context.Background(), tt.id)
            assert.ErrorIs(t, err, tt.wantErr)
            assert.Equal(t, tt.want, got)
        })
    }
}
```

## Performance

- Use `sync.Pool` for frequently allocated objects
- Preallocate slices when the size is known: `make([]T, 0, n)`
- Use `strings.Builder` for string concatenation in loops
- Avoid premature optimization — profile first with `pprof`
- Use `go vet`, `staticcheck`, and `golangci-lint` for static analysis

## Naming

- Use `MixedCaps` (not underscores) — `userID` not `user_id`
- Acronyms are all caps: `HTTPHandler`, `userID`, `xmlParser`
- Package names are short, lowercase, singular: `user`, `order`, `auth`
- Avoid stuttering: `user.User` is fine, `user.UserService` is not — use `user.Service`
- Variable names scale with scope: `i` for loop index, `userRepository` for package-level

## Recommended Scope

- **Scope**: Both (Global for Go-heavy developers, Project-level for mixed-stack teams)
- **Global**: `npx skills add skingford/skills --skill go-pro -g -y`
- **Project**: `npx skills add skingford/skills --skill go-pro -y`
