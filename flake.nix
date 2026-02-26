{
  description = "Phoenix + Claude Code devenv template";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      eachSystem = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in {
      templates.default = {
        path = ./templates/default;
        description = "Elixir + Phoenix with devenv, Expert LSP, and Claude Code";
      };

      packages = eachSystem (pkgs: {
        default = pkgs.writeShellApplication {
          name = "phoenix-new";
          runtimeInputs = [ pkgs.git ];
          text = ''
            name="''${1:?Usage: nix run github:onnimonni/phoenix-starter -- <project-name>}"
            APP_NAME="$(echo "$name" | tr '-' '_')"

            if [ -d "$name" ] && [ "$(ls -A "$name" 2>/dev/null)" ]; then
              echo "error: '$name' already exists and is not empty" >&2
              exit 1
            fi

            if ! command -v devenv &>/dev/null; then
              echo "error: devenv not found — install: https://devenv.sh/getting-started/" >&2
              exit 1
            fi

            mkdir -p "$name"
            cp -a ${./templates/default}/. "$name/"
            chmod -R u+w "$name"
            git -C "$name" init -q

            echo "Setting up Phoenix project: $APP_NAME"
            (cd "$name" && devenv shell -- bash -c "
              set -euo pipefail
              step_start=\$(date +%s)
              step_done() { local now; now=\$(date +%s); echo \"  ✓ \$1 (\$(( now - step_start ))s)\"; step_start=\$now; }

              mix archive.install hex phx_new --force >/dev/null 2>&1
              mix phx.new $APP_NAME --no-install >/dev/null 2>&1
              step_done 'Phoenix scaffold'

              shopt -s dotglob
              mv $APP_NAME/* .
              rmdir $APP_NAME

              elixir \"\$PHOENIX_STARTER_PATH/scripts/add_igniter.exs\" >/dev/null
              mix deps.get >/dev/null 2>&1
              step_done 'Dependencies installed'

              mkdir -p lib/mix/tasks
              cp \"\$PHOENIX_STARTER_PATH/scripts/configure_devenv.ex\" lib/mix/tasks/
              mix configure_devenv --yes >/dev/null 2>&1
              rm -f lib/mix/tasks/configure_devenv.ex

              mix format >/dev/null 2>&1
              step_done 'Configured for devenv'

              git add .
              git commit --no-gpg-sign --quiet -m 'Init Phoenix project'
              step_done 'Initial commit'
            ") 2>/dev/null || true

            if [ ! -f "$name/mix.exs" ]; then
              echo "error: setup failed" >&2
              exit 1
            fi

            # Start postgres, run ecto.setup, then stop
            (cd "$name" && devenv up -d) >/dev/null 2>&1
            (cd "$name" && devenv shell -- bash -c "
              set -euo pipefail
              step_start=\$(date +%s)
              step_done() { local now; now=\$(date +%s); echo \"  ✓ \$1 (\$(( now - step_start ))s)\"; step_start=\$now; }
              for i in \$(seq 1 30); do
                pg_isready -h 127.0.0.1 -q && break
                sleep 1
              done
              mix ecto.setup >/dev/null 2>&1
              step_done 'Database ready'
            ") 2>/dev/null
            (cd "$name" && devenv processes down) >/dev/null 2>&1

            if command -v direnv &>/dev/null; then
              direnv allow "$name"
            fi

            echo ""
            echo "Everything ready. Start developing your app:"
            echo "  cd $name && devenv up"
          '';
        };
      });
    };
}
