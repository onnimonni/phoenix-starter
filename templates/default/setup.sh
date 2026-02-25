#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${1:?Usage: ./setup.sh my_app}"

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

# Fetch new dependencies
mix deps.get

echo ""
echo "Done! Next steps:"
echo "  1. devenv up        # start postgres"
echo "  2. mix ecto.setup   # create + migrate DB"
echo "  3. mix phx.server   # start dev server"
