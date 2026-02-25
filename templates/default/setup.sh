#!/usr/bin/env bash
set -euo pipefail

# Default to directory name (hyphens → underscores for Elixir compatibility)
APP_NAME="${1:-$(basename "$PWD" | tr '-' '_')}"

echo "Creating Phoenix project: $APP_NAME"
mix archive.install hex phx_new --force
mix phx.new "$APP_NAME" --install

# Move generated files up to project root
shopt -s dotglob
mv "$APP_NAME"/* .
rmdir "$APP_NAME"

# Inject credo and sobelow into mix.exs deps
sd -F '{:phoenix,' '{:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      {:phoenix,' mix.exs

# Patch Ecto config for devenv (env vars, no password, 127.0.0.1)
for config_file in config/dev.exs config/test.exs; do
  sd -F 'username: "postgres"' 'username: System.get_env("USER", "postgres")' "$config_file"
  sd -F 'password: "postgres",' '' "$config_file"
  sd -F 'hostname: "localhost"' 'hostname: "127.0.0.1"' "$config_file"
done
sd -F "database: \"${APP_NAME}_dev\"" 'database: System.get_env("DATABASE_DEV", "app_dev")' config/dev.exs
sd -F "database: \"${APP_NAME}_test\"" 'database: System.get_env("DATABASE_TEST", "app_test")' config/test.exs

# Fetch new dependencies
mix deps.get

# Self-remove (one-time script)
rm -f setup.sh

echo ""
echo "Done! Next steps:"
echo "  1. devenv up        # start postgres"
echo "  2. mix ecto.setup   # create + migrate DB"
echo "  3. mix phx.server   # start dev server"
