---
name: otp
description: Use when working with GenServer, Supervisor, Task, ETS, Agent, Registry, Broadway, or any OTP pattern. Invoke BEFORE exploring code.
file_patterns:
  - "**/*_server.ex"
  - "**/*_worker.ex"
  - "**/*_supervisor.ex"
  - "**/application.ex"
auto_suggest: true
---

# OTP Thinking

## The Iron Law

**GenServer is a bottleneck by design.** It processes one message at a time. Every `call` serializes through a single process. This is a feature (serialized state access), not a bug -- but it means GenServer should never be your first choice.

## ETS Pattern

When you need shared readable state with serialized writes:

```elixir
# GenServer owns the table, writes serialize through it
# Reads bypass the GenServer entirely
def init(_) do
  table = :ets.new(__MODULE__, [:set, :protected, :named_table, read_concurrency: true])
  {:ok, %{table: table}}
end

def get(key), do: :ets.lookup(__MODULE__, key)  # No GenServer call!
def put(key, val), do: GenServer.call(__MODULE__, {:put, key, val})  # Serialized write
```

## GenServer Patterns

### call vs cast

- **`call`**: Synchronous, returns result. Use for queries and operations where caller needs confirmation.
- **`cast`**: Fire-and-forget. Use only when losing messages is acceptable. Prefer `call` by default.

### `handle_continue/2`

Deferred initialization -- runs after `init` returns but before any messages:

```elixir
def init(opts) do
  {:ok, %{}, {:continue, :load_data}}
end

def handle_continue(:load_data, state) do
  data = expensive_load()
  {:noreply, Map.put(state, :data, data)}
end
```

## Task Patterns

| Pattern | Use Case |
|---------|----------|
| `Task.Supervisor.async_nolink/2` | Fire task, await result, don't crash caller if task dies |
| `Task.Supervisor.start_child/2` | Fire-and-forget supervised task |
| `Task.async/1` | Only in scripts/tests -- linked, crashes caller |

**Never use `Task.async` in production.** Always use `Task.Supervisor`.

## DynamicSupervisor + Registry

Named dynamic processes:

```elixir
# Start
DynamicSupervisor.start_child(MySup, {Worker, name: via_tuple(id)})

# Lookup
defp via_tuple(id), do: {:via, Registry, {MyRegistry, id}}
```

**Never create atoms dynamically** (`String.to_atom`). Use Registry for dynamic naming.

## Process Discovery

| Scope | Mechanism |
|-------|-----------|
| Local node | `Registry` |
| Distributed | `:pg` (process groups) |

## Broadway vs Oban

| | Broadway | Oban |
|--|---------|------|
| Source | External queues (SQS, Kafka, RabbitMQ) | Database-backed job queue |
| Guarantee | At-least-once from external source | Exactly-once via DB unique constraints |
| Scaling | Concurrent pipeline stages | Queue-based concurrency limits |

## Supervision Strategies

| Strategy | When |
|----------|------|
| `one_for_one` | Children are independent |
| `one_for_all` | Children are interdependent (all must restart) |
| `rest_for_one` | Sequential dependency (later children depend on earlier) |

## Abstraction Decision Tree

```
Need mutable state at runtime?
├─ No → Module with functions (no process!)
└─ Yes
   ├─ Simple get/set → Agent
   └─ Complex behavior
      ├─ Fixed number → GenServer under Supervisor
      └─ Dynamic number → GenServer under DynamicSupervisor + Registry
         ├─ Need request/response? → GenServer (call/cast)
         └─ Need explicit state machine? → :gen_statem
```

## Storage Options

| Storage | Persistence | Speed | Use For |
|---------|------------|-------|---------|
| ETS | Process lifetime | Fast reads | Caches, lookup tables |
| `:persistent_term` | Until changed | Fastest reads (no copy) | Config, rarely-changed data |
| DETS | Disk | Slow | Small persistent stores |
| Mnesia | Disk + distributed | Medium | Distributed state (avoid if possible) |

## Debugging

```elixir
# Get GenServer state
:sys.get_state(pid)

# Trace messages
:sys.trace(pid, true)

# Statistics
:sys.statistics(pid, true)
```

## Telemetry

Prefer `:telemetry` over custom logging for observability. Emit events, attach handlers separately.

## Red Flags

| You're Thinking | Reality |
|----------------|---------|
| "I need a GenServer for this" | Do you need mutable state? Use a module. |
| "GenServer for a cache" | Use ETS with GenServer as owner. |
| "Task.async for background work" | Use Task.Supervisor in production. |
| "I'll create atoms for process names" | Use Registry. Atoms are never GC'd. |
| "Agent for complex state" | Agent is for simple get/set. Use GenServer. |
