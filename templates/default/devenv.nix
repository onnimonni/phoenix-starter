{ pkgs, ... }:

{
  # Add project-specific packages
  # packages = [ pkgs.imagemagick ];

  # Override database names
  # services.postgres.initialDatabases = [{ name = "myapp_dev"; } { name = "myapp_test"; }];

  enterShell = ''
    if [ ! -f mix.exs ]; then
      echo ""
      echo "  No mix.exs found. Create a Phoenix project:"
      echo "    bash setup.sh <app_name>"
      echo ""
    fi
  '';
}
