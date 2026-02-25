---
name: elixir
description: Use when writing ANY Elixir code (.ex/.exs). Covers core paradigm, control flow, data modeling, testing. Invoke BEFORE exploring code.
file_patterns:
  - "**/*.ex"
  - "**/*.exs"
auto_suggest: true
---

# Elixir Thinking

## The Iron Law

**No process without a runtime reason.** Only create a process for: mutable state, concurrent execution, or fault isolation. Never for code organization.

## Three Decoupled Dimensions

Elixir separates what OOP conflates:

| Dimension | Mechanism | NOT |
|-----------|-----------|-----|
| Behavior | Modules + functions | Classes |
| State | Data structures (maps, structs) | Instance variables |
| Mutability | Processes (GenServer, Agent) | Objects |

A module with pure functions is idiomatic. Not everything needs a process.

## "Let It Crash" = "Let It Heal"

Supervisors restart processes. But this does NOT mean ignore all errors:

- **Expected errors** (user input, API failures): Handle explicitly with `{:ok, _}` / `{:error, _}`
- **Unexpected errors** (bugs, impossible states): Let crash, supervisor heals
- **Never**: `try/rescue` around GenServer calls. Never `catch :exit`. Never restart loops in `handle_info`

## Control Flow

### Pattern Matching First

```elixir
# BAD
def process(data) do
  if data.type == :admin, do: admin_action(data), else: user_action(data)
end

# GOOD
def process(%{type: :admin} = data), do: admin_action(data)
def process(%{type: :user} = data), do: user_action(data)
```

### `with` for Chaining Fallible Operations

```elixir
with {:ok, user} <- find_user(id),
     {:ok, token} <- generate_token(user),
     {:ok, _} <- send_email(user, token) do
  {:ok, token}
end
# Automatically returns first non-matching result
```

**Never** use catch-all `_ ->` in `with` else clauses. Let non-matching tuples propagate.

### Pipe Operator

```elixir
# BAD
result = step3(step2(step1(input)))

# GOOD
input |> step1() |> step2() |> step3()
```

Always use parens in pipes: `|> foo()` not `|> foo`.

## Polymorphism Hierarchy

Use the simplest mechanism that works:

1. **Pattern matching** on function heads
2. **Anonymous functions** for runtime dispatch
3. **Behaviours** for contracts (`@callback`)
4. **Protocols** for type-based dispatch across unrelated types
5. **Message passing** only when process isolation needed

## Data Modeling

- Structs for domain entities with `@enforce_keys`
- Embedded schemas for validation without DB
- Tagged tuples: `{:ok, value}`, `{:error, reason}`
- Avoid deeply nested maps; flatten or use structs

## Defaults and Options

```elixir
# Provide /2 with defaults, /3 for full control
def fetch(url), do: fetch(url, [])
def fetch(url, opts) do
  timeout = Keyword.get(opts, :timeout, 5_000)
  # ...
end
```

## Rules

1. **Pattern matching over if/else** -- always
2. **`@impl true`** before every callback (mount, handle_event, init, etc.)
3. **ok/error tuples** for all fallible operations
4. **`with`** for sequential fallible operations
5. **Pipe operator** for data transformation chains
6. **Never nest if/else** -- use `case`, `cond`, or pattern matching
7. **Predicate `?` / dangerous `!`** naming conventions
8. **Let it crash** -- don't rescue unexpected errors

## Idioms

- Process dictionary is unidiomatic; pass state explicitly
- `is_thing` naming only for guard-compatible functions
- Prepend to lists (`[h | tail]`), never append
- `dbg/1` for debugging (Elixir 1.14+)
- Built-in `JSON` module (Elixir 1.18+) -- prefer over Jason for new projects
- Use `for` comprehensions over `Enum.map` + `Enum.filter` chains
- IO lists over string concatenation for building output

## Testing

- Test behavior, not implementation
- Keep tests `async: true` unless they share DB state
- `@tag :tmp_dir` for filesystem tests
- Use `ExUnit.CaptureLog` / `ExUnit.CaptureIO` for side effects
- Avoid mocking; use behaviours + test implementations

## Red Flags

| You're Thinking | Reality |
|----------------|---------|
| "I'll wrap this in a GenServer" | Do you need mutable state? Probably not. |
| "Let me create a module for organizing" | Modules ≠ processes. Just use functions. |
| "I'll add a supervisor for safety" | Supervisors are for processes, not error handling. |
| "try/rescue to handle errors" | Use pattern matching on return values. |
| "I'll use String.concat in a loop" | Use IO lists. |
