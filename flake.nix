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

            echo "Setting up Phoenix project: $name"
            (cd "$name" && devenv shell -- bash setup.sh) || true

            if [ ! -f "$name/mix.exs" ]; then
              echo "error: setup failed — run manually: cd $name && devenv shell -- bash setup.sh" >&2
              exit 1
            fi

            if command -v direnv &>/dev/null; then
              direnv allow "$name"
            fi

            echo ""
            echo "Done! Next:"
            echo "  cd $name"
            echo "  devenv up     # start postgres"
            echo "  mix ecto.setup"
            echo "  mix phx.server"
          '';
        };
      });
    };
}
