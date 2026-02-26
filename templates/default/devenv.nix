# Inherits Elixir, PostgreSQL, hooks, and skills from github:onnimonni/phoenix-starter
{ pkgs, ... }:

{
  # Add project-specific packages
  # packages = [ pkgs.imagemagick ];

  # Override Elixir version (default: beam.packages.erlang_28.elixir_1_20)
  # languages.elixir.package = pkgs.beam.packages.erlang_27.elixir_1_18;

  # Override database names
  # services.postgres.initialDatabases = [{ name = "myapp_dev"; } { name = "myapp_test"; }];

}
