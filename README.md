# Phoenix + Claude Code Devenv Template

Batteries-included Elixir dev environment with [devenv](https://devenv.sh), [Expert LSP](https://github.com/elixir-lang/expert), and Claude Code integration.

## Quick Start

Prerequisites: [nix](https://nixos.org/download) and [devenv](https://devenv.sh/getting-started/)

```sh
nix run github:onnimonni/phoenix-starter -- my_app
cd my_app
devenv up  # starts postgres + phoenix on http://localhost:4000
```

The installer scaffolds Phoenix, injects deps (igniter, credo, sobelow), patches Ecto config, and runs `mix ecto.setup`. First run takes a few minutes.

## Adding to Existing Project

Add to your `devenv.yaml`:

```yaml
inputs:
  nixpkgs:
    url: github:cachix/devenv-nixpkgs/rolling
  expert:
    url: github:elixir-lang/expert
  phoenix-starter:
    url: github:onnimonni/phoenix-starter
    flake: false

imports:
  - phoenix-starter
```

Copy `.credo.exs` from [`templates/default/.credo.exs`](templates/default/.credo.exs) to your project root. It references upstream credo checks via `PHOENIX_STARTER_PATH` env var (auto-set by the module).

## How Setup Works

The `nix run` installer runs `mix phx.new`, moves files to project root, then:

1. **Bootstraps Igniter** -- injects `{:igniter, "~> 0.5"}` into mix.exs via string replacement ([`scripts/add_igniter.exs`](scripts/add_igniter.exs))
2. **Runs Igniter task** -- adds credo + sobelow deps, patches Ecto config for devenv ([`scripts/configure_devenv.ex`](scripts/configure_devenv.ex))
3. **Formats** -- `mix format` for consistent output

The Igniter task is copied into `lib/mix/tasks/` temporarily, run with `mix configure_devenv --yes`, then deleted. Igniter stays as a permanent dev dep for future use (`mix igniter.add`, code generation, etc).

## What's Included

- **Elixir 1.20-rc** (OTP 28) via devenv
- **Expert LSP** -- official Elixir language server
- **Igniter** -- AST-aware code generation and project configuration
- **Git pre-commit hooks** -- mix format, compile warnings-as-errors, credo strict, sobelow
- **Claude Code hooks** -- auto-format, compile, credo, sobelow (PostToolUse) + skill reminder (PreToolUse)
- **Custom Credo checks** -- 5 AST-based checks (missing @impl, hardcoded config, deprecated patterns, string concat, auto-upload)
- **Claude Code slash commands** -- `/test`, `/format`, `/credo`, `/sobelow`
- **PostgreSQL** -- auto-managed with dev + test databases
- **7 Elixir skills** -- elixir, phoenix-liveview, ecto, otp, oban, phoenix-uploads, testing
- **Worktree DB isolation** -- automatic database cloning for Claude Code worktrees

## How Updates Work

| Resource | Method | Auto-updates? |
|----------|--------|---------------|
| Skills (`.claude/skills/`) | Overwritten on shell entry | Yes, on `devenv update` |
| Worktree hooks (`.claude/hooks/`) | Overwritten on shell entry | Yes, on `devenv update` |
| Credo checks (`credo_checks/`) | Referenced via `PHOENIX_STARTER_PATH` | Yes, on `devenv update` |
| Setup scripts (`scripts/`) | Referenced via `PHOENIX_STARTER_PATH` | Yes, on `devenv update` |
| `.credo.exs` | Consumer-owned (from template) | No, customize freely |
| `CLAUDE.md` | Consumer-owned (from template) | No, customize freely |

Update upstream: `devenv update phoenix-starter`

## PostgreSQL

`devenv up` starts both PostgreSQL and Phoenix (`mix phx.server`). Two databases are pre-created: `app_dev` and `app_test`.

```sh
devenv up        # foreground (postgres + phoenix)
devenv up -d     # background
psql -h 127.0.0.1 app_dev
```

Ecto config is auto-patched during setup via Igniter:

```elixir
# config/dev.exs (after setup)
config :my_app, MyApp.Repo,
  username: System.get_env("USER", "postgres"),
  password: "postgres",
  hostname: "127.0.0.1",
  database: System.get_env("DATABASE_DEV", "app_dev"),
  ...
```

### Worktree Database Isolation

When Claude Code creates a worktree, the hook automatically clones `app_dev` and `app_test` using PostgreSQL `TEMPLATE` (instant, copy-on-write) and writes `.env.worktree` with `DATABASE_DEV` and `DATABASE_TEST` env vars. Databases are dropped when the worktree is removed.

## Credits

Skills merged from:
- [claude-code-elixir](https://github.com/georgeguimaraes/claude-code-elixir) by George Guimaraes (Apache-2.0)
- [elixir-phoenix-guide](https://github.com/j-morgan6/elixir-phoenix-guide) by j-morgan6 (MIT)

## License

MIT
