#!/usr/bin/env bash
set -euo pipefail

# Default to directory name (hyphens -> underscores for Elixir compatibility)
APP_NAME="${1:-$(basename "$PWD" | tr '-' '_')}"

echo "Creating Phoenix project: $APP_NAME"
mix archive.install hex phx_new --force
mix phx.new "$APP_NAME" --no-install

# Move generated files up to project root
shopt -s dotglob
mv "$APP_NAME"/* .
rmdir "$APP_NAME"

# Bootstrap igniter into the project (simple string injection, no deps needed)
elixir "$PHOENIX_STARTER_PATH/scripts/add_igniter.exs"
mix deps.get

# Use Igniter to add dev deps (credo, sobelow) and patch Ecto config for devenv
mkdir -p lib/mix/tasks
cp "$PHOENIX_STARTER_PATH/scripts/configure_devenv.ex" lib/mix/tasks/
mix configure_devenv --yes
rm -f lib/mix/tasks/configure_devenv.ex

mix deps.get
mix format

# Self-remove (one-time script)
rm -f setup.sh

echo ""
echo "Done! Next steps:"
echo "  1. devenv up        # start postgres"
echo "  2. mix ecto.setup   # create + migrate DB"
echo "  3. mix phx.server   # start dev server"
