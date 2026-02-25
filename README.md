# Phoenix + Claude Code Devenv Template

Batteries-included Elixir dev environment with [devenv](https://devenv.sh), [Expert LSP](https://github.com/elixir-lang/expert), and Claude Code integration.

## Quick Start

```sh
mkdir my_app && cd my_app
nix flake init -t github:onnimonni/phoenix-starter
devenv shell
bash setup.sh my_app
```

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

## setup.sh

Scaffolds a new Phoenix project inside the current directory:

```sh
./setup.sh my_app
```

This runs `mix phx.new`, moves files to project root, injects `credo` + `sobelow` deps, and fetches dependencies.

## What's Included

- **Elixir 1.20-rc** (OTP 28) via devenv
- **Expert LSP** -- official Elixir language server
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
| `.credo.exs` | Consumer-owned (from template) | No, customize freely |
| `CLAUDE.md` | Consumer-owned (from template) | No, customize freely |

Update upstream: `devenv update phoenix-starter`

## PostgreSQL

PostgreSQL starts with `devenv up`. Two databases are pre-created: `app_dev` and `app_test`.

```sh
devenv up        # foreground
devenv up -d     # background
psql -h 127.0.0.1 app_dev
```

Configure Ecto:

```elixir
# config/dev.exs
config :my_app, MyApp.Repo,
  username: System.get_env("USER"),
  database: System.get_env("DATABASE_DEV", "app_dev"),
  hostname: "127.0.0.1",
  pool_size: 10
```

### Worktree Database Isolation

When Claude Code creates a worktree, the hook automatically clones `app_dev` and `app_test` using PostgreSQL `TEMPLATE` (instant, copy-on-write) and writes `.env.worktree` with `DATABASE_DEV` and `DATABASE_TEST` env vars. Databases are dropped when the worktree is removed.

## Credits

Skills merged from:
- [claude-code-elixir](https://github.com/georgeguimaraes/claude-code-elixir) by George Guimaraes (Apache-2.0)
- [elixir-phoenix-guide](https://github.com/j-morgan6/elixir-phoenix-guide) by j-morgan6 (MIT)

## License

MIT
