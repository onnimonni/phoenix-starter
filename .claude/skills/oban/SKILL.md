---
name: oban
description: Use when working with Oban jobs, workers, queues, workflows, or background processing. Invoke BEFORE exploring code.
file_patterns:
  - "**/*_worker.ex"
  - "**/*_job.ex"
  - "**/workers/**"
auto_suggest: true
---

# Oban Thinking

## The Iron Law

**JSON serialization changes your data.** Oban args are stored as JSON. Atoms become strings, structs lose their type, tuples become arrays.

```elixir
# BAD - atom key lost
%{status: :active} |> Jason.encode!() |> Jason.decode!()
# => %{"status" => "active"}  -- string key, string value

# GOOD - design for string keys from the start
@impl Oban.Worker
def perform(%Oban.Job{args: %{"user_id" => user_id, "action" => action}}) do
  # Pattern match on string keys and values
  case action do
    "activate" -> Accounts.activate(user_id)
    "deactivate" -> Accounts.deactivate(user_id)
  end
end
```

## Let It Crash

Don't wrap job logic in try/rescue. Oban handles failures:

```elixir
# BAD
def perform(%Oban.Job{args: args}) do
  try do
    do_work(args)
  rescue
    e -> {:error, e}
  end
end

# GOOD - let it crash, Oban retries automatically
def perform(%Oban.Job{args: %{"id" => id}}) do
  record = Repo.get!(Record, id)  # Crashes if not found = correct
  process(record)
  :ok
end
```

## Snoozing for Polling

When a job needs to wait for an external condition:

```elixir
def perform(%Oban.Job{args: %{"order_id" => id}}) do
  case Orders.check_payment(id) do
    :paid -> {:ok, :completed}
    :pending -> {:snooze, 60}  # Check again in 60 seconds
    :failed -> {:error, "Payment failed"}
  end
end
```

## Unique Jobs

Prevent duplicate processing:

```elixir
use Oban.Worker,
  queue: :default,
  unique: [period: 300, fields: [:args, :queue], states: [:available, :scheduled, :executing]]
```

## High Throughput: Chunking

For bulk operations, insert jobs in chunks:

```elixir
user_ids
|> Enum.chunk_every(100)
|> Enum.each(fn chunk ->
  chunk
  |> Enum.map(&MyWorker.new(%{user_id: &1}))
  |> Oban.insert_all()
end)
```

## Simple Job Chaining

Without Oban Pro, chain jobs manually:

```elixir
def perform(%Oban.Job{args: %{"step" => "extract", "id" => id}}) do
  data = extract(id)
  %{step: "transform", id: id, data: data}
  |> __MODULE__.new()
  |> Oban.insert!()
  :ok
end
```

## Worker Configuration

```elixir
use Oban.Worker,
  queue: :emails,
  max_attempts: 5,
  priority: 1  # 0 = highest priority
```

## Return Values

| Return | Effect |
|--------|--------|
| `:ok` | Job completed successfully |
| `{:ok, value}` | Completed, value available in Pro workflows |
| `{:error, reason}` | Failed, will retry |
| `{:snooze, seconds}` | Reschedule after delay |
| `{:cancel, reason}` | Cancel permanently, no more retries |
| `{:discard, reason}` | Discard permanently (deprecated, use cancel) |

## Oban Pro: Workflows

Complex job dependency graphs:

```elixir
alias Oban.Pro.Workflow

Workflow.new(workflow_id: "import-#{id}")
|> Workflow.add(:extract, ExtractWorker.new(%{id: id}))
|> Workflow.add(:transform, TransformWorker.new(%{id: id}), deps: [:extract])
|> Workflow.add(:load, LoadWorker.new(%{id: id}), deps: [:transform])
|> Oban.insert_all()
```

### Recorded Values

Pass data between workflow steps:

```elixir
# In ExtractWorker
def perform(job) do
  data = extract(job.args["id"])
  {:ok, data}  # This value is recorded
end

# In TransformWorker
def perform(job) do
  {:ok, extract_data} = Oban.Pro.Workflow.fetch_recorded(job, :extract)
  transform(extract_data)
end
```

### Fan-Out / Fan-In

```elixir
Workflow.new()
|> Workflow.add(:split, SplitWorker.new(%{id: id}))
|> Workflow.add(:process_1, ProcessWorker.new(%{chunk: 1}), deps: [:split])
|> Workflow.add(:process_2, ProcessWorker.new(%{chunk: 2}), deps: [:split])
|> Workflow.add(:merge, MergeWorker.new(%{}), deps: [:process_1, :process_2])
|> Oban.insert_all()
```

## Testing

```elixir
use Oban.Testing, repo: MyApp.Repo

test "enqueues welcome email" do
  Accounts.register(%{email: "test@example.com"})
  assert_enqueued worker: WelcomeEmailWorker, args: %{email: "test@example.com"}
end

test "processes job" do
  :ok = perform_job(WelcomeEmailWorker, %{email: "test@example.com"})
end
```

## Red Flags

| You're Thinking | Reality |
|----------------|---------|
| "I'll use atom keys in args" | They become strings in JSON. |
| "try/rescue in perform" | Let Oban handle retries. |
| "Task.async for background work" | Use Oban -- it persists, retries, dedupes. |
| "I'll store structs in args" | JSON doesn't preserve Elixir types. |
