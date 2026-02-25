---
name: phoenix-liveview
description: Use when working with Phoenix LiveView, components, PubSub, channels, sockets, or any .heex template. Invoke BEFORE exploring code.
file_patterns:
  - "**/*_live.ex"
  - "**/*_live/**"
  - "**/*.heex"
  - "**/router.ex"
  - "**/endpoint.ex"
auto_suggest: true
---

# Phoenix LiveView Thinking

## The Iron Law

**No database queries in mount.** Mount is called TWICE (once for HTTP, once for WebSocket). Side effects in mount execute twice.

```elixir
# BAD - query runs twice
@impl true
def mount(_params, _session, socket) do
  users = Repo.all(User)  # Runs on HTTP AND WebSocket connect
  {:ok, assign(socket, users: users)}
end

# GOOD - query only on connected
@impl true
def mount(_params, _session, socket) do
  socket = if connected?(socket) do
    assign(socket, users: Accounts.list_users())
  else
    assign(socket, users: [])
  end
  {:ok, socket}
end

# BEST - use assign_async
@impl true
def mount(_params, _session, socket) do
  {:ok, assign_async(socket, :users, fn -> {:ok, %{users: Accounts.list_users()}} end)}
end
```

## Two-Phase Rendering

1. **Disconnected (HTTP)**: Static HTML for SEO/fast paint. No WebSocket yet.
2. **Connected (WebSocket)**: Full interactivity. `connected?(socket)` returns true.

Initialize ALL assigns in mount (even empty) to avoid "key not found" in templates.

## Lifecycle

```
mount/3 → handle_params/3 → render/1
                ↑
handle_event/3 ─┘ (user interaction)
handle_info/2  ─┘ (PubSub, send/2)
```

## Rules

1. **`@impl true`** before every callback
2. **Initialize ALL assigns in mount/3** -- even with defaults/empty values
3. **`connected?(socket)`** gates side effects (subscriptions, async loads)
4. **`Map.get(assigns, :key, default)`** for optional assigns in components
5. **ok/error tuples** -- `{:ok, socket}`, `{:noreply, socket}`, `{:reply, map, socket}`
6. **`with`** for error handling in handle_event
7. **Never `auto_upload: true`** with form submission (use manual upload)

## Scopes (Phoenix 1.8+)

Security-first access control:

```elixir
# In router
scope "/admin", MyAppWeb do
  pipe_through [:browser, :require_admin]
  live "/dashboard", AdminLive.Dashboard
end
```

## PubSub

Topics must be scoped to prevent data leaks:

```elixir
# BAD - anyone sees all updates
Phoenix.PubSub.subscribe(MyApp.PubSub, "posts")

# GOOD - scoped to user
Phoenix.PubSub.subscribe(MyApp.PubSub, "posts:#{current_user.id}")
```

## Components

| Type | Owns State? | Owns URL? | Use For |
|------|-------------|-----------|---------|
| Functional component | No | No | Display, formatting |
| LiveComponent | Yes | No | Reusable stateful UI |
| LiveView | Yes | Yes | Pages, routes |

## Async Data Loading

```elixir
# assign_async - loads data without blocking render
{:ok, assign_async(socket, :users, fn ->
  {:ok, %{users: Accounts.list_users()}}
end)}

# In template
<.async_result :let={users} assign={@users}>
  <:loading>Loading...</:loading>
  <:failed :let={_reason}>Failed to load</:failed>
  <%= for user <- users do %>
    <p><%= user.name %></p>
  <% end %>
</.async_result>
```

## Streams (Large Collections)

```elixir
# mount
{:ok, stream(socket, :songs, Music.list_songs())}

# template - use @streams not @songs
<div id="songs" phx-update="stream">
  <div :for={{dom_id, song} <- @streams.songs} id={dom_id}>
    <%= song.title %>
  </div>
</div>
```

## Flash Messages

```elixir
socket |> put_flash(:info, "Saved!") |> push_navigate(to: ~p"/items")
```

## Navigation

```elixir
# Full page navigation (new mount)
push_navigate(socket, to: ~p"/items")

# Patch (same LiveView, triggers handle_params)
push_patch(socket, to: ~p"/items?page=2")

# In templates
<.link navigate={~p"/items"}>Items</.link>
<.link patch={~p"/items?page=2"}>Page 2</.link>
```

**Deprecated**: `live_redirect`, `live_patch` -- use `<.link navigate={}>` / `<.link patch={}>`.

## Gotchas

- **`terminate/2`** requires `Process.flag(:trap_exit, true)` in mount
- **`start_async`** duplicate names silently fail -- use unique names
- **CSS `box-shadow`** is clipped by `clip-path` -- use `filter: drop-shadow()` instead
- **Upload `content_type`** is client-provided and untrusted -- validate server-side
- **Read body before `Plug.Parsers`** for webhook signature verification
- **External polling**: Use a GenServer, not LiveView (LiveView dies with socket)

## Deprecated Patterns

| Old | New |
|-----|-----|
| `form_for(@changeset)` | `<.form for={to_form(@changeset)}>` |
| `live_redirect` | `<.link navigate={path}>` |
| `live_patch` | `<.link patch={path}>` |
| `.flash_group` | Removed in Phoenix 1.8+ |
