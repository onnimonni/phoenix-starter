# Elixir + Phoenix Project

## Skill Routing

Invoke the matching skill BEFORE exploring or writing code:

| Trigger | Skill |
|---------|-------|
| `.ex`/`.exs` files, Elixir patterns, modules, functions | `elixir` |
| LiveView, `.heex`, mount, handle_event, PubSub, socket | `phoenix-liveview` |
| Schema, changeset, Repo, migration, context, Ecto query | `ecto` |
| GenServer, Supervisor, Task, ETS, Agent, Registry | `otp` |
| Oban, Worker, job queue, background job, workflow | `oban` |
| File upload, allow_upload, consume_uploaded_entries | `phoenix-uploads` |
| Tests, ExUnit, DataCase, ConnCase, test helpers | `testing` |

## Dev Commands

- `mix format` -- format code
- `mix compile --warnings-as-errors` -- compile with strict warnings
- `mix credo --strict` -- static analysis
- `mix test` -- run test suite
- `mix deps.get` -- fetch dependencies

## Architecture Principles

- **Use red/green TTD**
- **Contexts as boundaries**: group related operations, cross-reference by ID not association
- **Thin LiveViews**: business logic in contexts, LiveViews only handle UI state
- **Pattern matching over conditionals**: use function heads, case, with -- never nested if/else
- **Let it crash**: handle expected errors explicitly, let unexpected ones crash and heal via supervisors
- **No process without runtime reason**: don't create GenServer for code organization

## Red Flags (invoke skill immediately)

- Writing a GenServer → invoke `otp`
- Database query in mount → invoke `phoenix-liveview`
- `try/rescue` in production code → invoke `elixir`
- Missing `@impl true` before callback → invoke `elixir`
- `form_for` or `live_redirect` → invoke `phoenix-liveview` (deprecated)
- String keys vs atom keys confusion → invoke `oban`
- N+1 query in template → invoke `ecto`
