%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "test/"],
        excluded: [~r"/_build/", ~r"/deps/"]
      },
      requires: ["credo_checks/**/*.ex"],
      strict: true,
      checks: %{
        enabled: [
          # Built-in checks that replace grep hooks
          {Credo.Check.Refactor.Nesting, [max_nesting: 2]},

          # Custom checks
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
