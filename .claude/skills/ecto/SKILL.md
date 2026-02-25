---
name: ecto
description: Use when working with Ecto schemas, changesets, queries, Repo, migrations, or context modules. Invoke BEFORE exploring code.
file_patterns:
  - "**/schemas/**"
  - "**/contexts/**"
  - "**/*_context.ex"
  - "**/repo.ex"
  - "**/migrations/**"
auto_suggest: true
---

# Ecto Thinking

## Context = Bounded Context

A context changes the meaning of entities. `Accounts.User` and `Billing.User` can reference the same DB table but expose different fields and operations.

### Cross-Context References

Use IDs, not associations:

```elixir
# BAD - tight coupling
schema "orders" do
  belongs_to :user, Accounts.User  # Context boundary violation
end

# GOOD - loose coupling
schema "orders" do
  field :user_id, :id
end
```

### CRUD Contexts Are Fine

Not every context needs DDD. `Accounts.list_users/0`, `Accounts.create_user/1` is valid.

## DDD as Pipelines

```elixir
def register_user(attrs) do
  %User{}                          # Build
  |> User.registration_changeset(attrs)  # Validate
  |> Repo.insert()                 # Persist
end
```

## Schema != Database Table

Three schema types:

| Type | DB? | Use For |
|------|-----|---------|
| `schema` | Yes | Database-backed entities |
| `embedded_schema` | No | Validation, forms, API params |
| Schemaless changeset | No | One-off validations |

## Multiple Changesets Per Schema

```elixir
defmodule User do
  def registration_changeset(user, attrs) do
    user |> cast(attrs, [:email, :password]) |> validate_required([:email, :password])
  end

  def profile_changeset(user, attrs) do
    user |> cast(attrs, [:name, :bio]) |> validate_length(:bio, max: 500)
  end
end
```

## Rules

1. **Always use changesets** for data validation
2. **Preload associations explicitly** -- never rely on lazy loading (it doesn't exist)
3. **Use transactions** (`Repo.transaction` / `Ecto.Multi`) for multi-step operations
4. **DB constraints AND changeset validations** -- both, always
5. **Use contexts** to group related operations
6. **Add indexes** on foreign keys and frequently queried columns
7. **`timestamps()`** in every schema

## Query Patterns

### Composable Queries

```elixir
def list_users(opts \\ []) do
  User
  |> maybe_filter_active(opts[:active])
  |> maybe_filter_role(opts[:role])
  |> Repo.all()
end

defp maybe_filter_active(query, nil), do: query
defp maybe_filter_active(query, active) do
  where(query, [u], u.active == ^active)
end
```

### Preloading

```elixir
# Separate query per association (N+1 safe)
Repo.all(User) |> Repo.preload(:posts)

# Join preload (single query, but watch memory on has_many)
from(u in User, preload: [posts: ^from(p in Post, order_by: p.inserted_at)])
|> Repo.all()
```

**Warning**: Join preloads on has_many can use 10x more memory (row duplication).

### Upserts

```elixir
Repo.insert(changeset,
  on_conflict: {:replace, [:name, :updated_at]},
  conflict_target: :email
)
```

## Transactions

```elixir
# Simple
Repo.transaction(fn ->
  case Repo.insert(changeset) do
    {:ok, record} -> record
    {:error, changeset} -> Repo.rollback(changeset)
  end
end)

# Multi (composable, named steps)
Ecto.Multi.new()
|> Ecto.Multi.insert(:user, user_changeset)
|> Ecto.Multi.insert(:profile, fn %{user: user} ->
  Profile.changeset(%Profile{user_id: user.id}, profile_attrs)
end)
|> Repo.transaction()
```

## Multi-Tenancy

- Composite foreign keys for data isolation
- `prepare_query/3` callback in Repo for automatic tenant scoping

## Gotchas

- **CTE queries don't inherit prefix** -- set prefix explicitly in CTE subqueries
- **Parameterized != prepared statements** -- Ecto parameterizes, Postgres may or may not cache
- **`pool_count` vs `pool_size`**: They multiply. 2 pools * 10 size = 20 connections
- **Sandbox mode** doesn't work with external processes (use `Ecto.Adapters.SQL.Sandbox.allow/3`)
- **Null bytes** in strings crash Postgres -- sanitize input
- **Preload ordering**: Use `preload_order` or inline query for association sorting
- **N+1 in templates**: If template accesses `user.posts`, preload before rendering
