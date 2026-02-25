# Elixir Devenv + Claude Code Template

Batteries-included Elixir dev environment with [devenv](https://devenv.sh), [Expert LSP](https://github.com/elixir-lang/expert), and Claude Code integration.

One command: `devenv shell` -- and you're ready.

## What's Included

- **Elixir 1.20-rc** (OTP 28) via devenv
- **Expert LSP** -- official Elixir language server
- **Git pre-commit hooks** -- mix format, compile warnings-as-errors, credo strict
- **Claude Code hooks** -- 3 PostToolUse (auto-format, compile, credo) + 10 PreToolUse (lint guards) + worktree DB cloning
- **Claude Code slash commands** -- `/test`, `/format`, `/credo`
- **PostgreSQL** -- auto-managed by devenv (dev + test databases)
- **7 Elixir skills** -- elixir, phoenix-liveview, ecto, otp, oban, phoenix-uploads, testing

## Setup

1. Install [devenv](https://devenv.sh/getting-started/)
2. Clone this repo
3. Run `devenv shell`
4. Start building

## PostgreSQL

PostgreSQL starts automatically with `devenv up`. Two databases are pre-created: `app_dev` and `app_test`.

```sh
# Start all services (postgres) in foreground
devenv up

# Or run in background
devenv up -d

# Connect
psql -h 127.0.0.1 app_dev
```

Data is stored in `.devenv/state/postgres/`. Configure your Ecto repo:

```elixir
# config/dev.exs
config :my_app, MyApp.Repo,
  username: System.get_env("USER"),
  database: "app_dev",
  hostname: "127.0.0.1",
  pool_size: 10
```

### Worktree Database Isolation

When Claude Code creates a worktree (`--worktree` flag or `isolation: "worktree"` in subagents), the WorktreeCreate hook automatically:

1. Creates a git worktree at `.claude/worktrees/<name>`
2. Clones `app_dev` and `app_test` databases using PostgreSQL `TEMPLATE` (instant, copy-on-write)
3. Writes `.env.worktree` with `DATABASE_DEV` and `DATABASE_TEST` env vars

When the worktree is removed, the cloned databases are dropped automatically.

To use the cloned DBs in your Ecto config:

```elixir
# config/dev.exs
config :my_app, MyApp.Repo,
  username: System.get_env("USER"),
  database: System.get_env("DATABASE_DEV", "app_dev"),
  hostname: "127.0.0.1",
  pool_size: 10
```

## Usage in Your Project

Copy this template into your Elixir project root. The `devenv.nix` declares everything -- packages, hooks, Claude Code integration. Skills live in `.claude/skills/`.

When you enter `devenv shell`, devenv auto-generates:
- `.claude/settings.json` -- hook configuration
- `.claude/commands/` -- slash commands
- Git pre-commit hooks

## Skills

| Skill | When to Use |
|-------|-------------|
| `elixir` | Any .ex/.exs file, core Elixir patterns |
| `phoenix-liveview` | LiveView, components, PubSub, .heex |
| `ecto` | Schemas, changesets, queries, migrations |
| `otp` | GenServer, Supervisor, Task, ETS |
| `oban` | Background jobs, workflows |
| `phoenix-uploads` | File uploads in LiveView |
| `testing` | ExUnit tests, fixtures, assertions |

## Credits

Skills merged from:
- [claude-code-elixir](https://github.com/georgeguimaraes/claude-code-elixir) by George Guimaraes (Apache-2.0)
- [elixir-phoenix-guide](https://github.com/j-morgan6/elixir-phoenix-guide) by j-morgan6 (MIT)

## License

MIT
