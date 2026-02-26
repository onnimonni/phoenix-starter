# Igniter Mix task to configure a fresh Phoenix project for devenv.
# Patches Ecto config (env vars, 127.0.0.1) and asset tool paths.
# Copied into project temporarily, run as: mix configure_devenv --yes

defmodule Mix.Tasks.ConfigureDevenv do
  @shortdoc "Configures Phoenix project for devenv"

  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def info(_argv, _composing_task) do
    %Igniter.Mix.Task.Info{schema: [], aliases: [], positional: []}
  end

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    app = Mix.Project.config()[:app]

    repo =
      app
      |> Atom.to_string()
      |> Macro.camelize()
      |> then(&Module.concat([&1, "Repo"]))

    igniter
    |> configure_repo("dev.exs", app, repo, "DATABASE_DEV", "app_dev")
    |> configure_repo("test.exs", app, repo, "DATABASE_TEST", "app_test")
    |> configure_asset_tools()
  end

  defp configure_repo(igniter, file, app, repo, db_env, db_default) do
    igniter
    |> force_configure(file, app, [repo, :username], ~s|System.get_env("USER", "postgres")|)
    |> force_configure(file, app, [repo, :hostname], ~s|"127.0.0.1"|)
    |> force_configure(file, app, [repo, :database], ~s|System.get_env("#{db_env}", "#{db_default}")|)
  end

  defp configure_asset_tools(igniter) do
    igniter
    |> configure_asset_tool(:esbuild, "ESBUILD_VERSION", "ESBUILD_BINARY_PATH")
    |> configure_asset_tool(:tailwind, "TAILWIND_VERSION", "TAILWIND_BINARY_PATH")
  end

  defp configure_asset_tool(igniter, tool, version_env, path_env) do
    # Read current version from compiled config (available at task runtime)
    current_version = Application.get_env(tool, :version, "0.0.0")

    version_code = "System.get_env(\"#{version_env}\") || \"#{current_version}\""
    path_code = "System.get_env(\"#{path_env}\")"

    igniter
    |> force_configure("config.exs", tool, [:version], version_code)
    |> force_configure("config.exs", tool, [:path], path_code)
  end

  # configure/5 won't override existing values; updater forces the replacement
  defp force_configure(igniter, file, app, path, code_str) do
    ast = Sourceror.parse_string!(code_str)

    Igniter.Project.Config.configure(
      igniter,
      file,
      app,
      path,
      {:code, ast},
      updater: fn zipper -> {:ok, Sourceror.Zipper.replace(zipper, ast)} end
    )
  end
end
