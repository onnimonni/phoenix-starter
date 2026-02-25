# Consumer-owned credo config
# Upstream checks auto-update via PHOENIX_STARTER_PATH env var (set by devenv module)
upstream = System.get_env("PHOENIX_STARTER_PATH", "")

upstream_requires =
  if upstream != "" and File.dir?(Path.join(upstream, "credo_checks")),
    do: [Path.join(upstream, "credo_checks/**/*.ex")],
    else: []

local_requires =
  if File.dir?("credo_checks"),
    do: ["credo_checks/**/*.ex"],
    else: []

%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "test/"],
        excluded: [~r"/_build/", ~r"/deps/"]
      },
      requires: upstream_requires ++ local_requires,
      strict: true,
      checks: %{
        enabled: [
          {Credo.Check.Refactor.Nesting, [max_nesting: 2]},
          {CredoChecks.Warning.MissingImplAnnotation, []},
          {CredoChecks.Warning.HardcodedConfig, []},
          {CredoChecks.Warning.DeprecatedPhoenixPattern, []},
          {CredoChecks.Warning.StringConcatInEnum, []},
          {CredoChecks.Warning.AutoUploadTrue, []}
        ]
      }
    }
  ]
}
