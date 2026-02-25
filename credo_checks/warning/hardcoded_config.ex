defmodule CredoChecks.Warning.HardcodedConfig do
  use Credo.Check,
    base_priority: :high,
    category: :warning,
    explanations: [
      check: """
      Configuration values like file paths and size limits should come from
      Application config, not be hardcoded in source code.

      Use `Application.get_env(:app, :config_key)` instead of literal values.
      """
    ]

  @path_var_names ~w(upload_path file_path uploads_dir)a
  @size_var_names ~w(max_file_size file_size_limit max_upload max_size)a

  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    source_file
    |> Credo.Code.prewalk(&traverse(&1, &2, issue_meta))
    |> Enum.reverse()
  end

  defp traverse({:=, _, [{name, meta, nil}, value]}, issues, issue_meta)
       when is_atom(name) do
    cond do
      name in @path_var_names and hardcoded_path?(value) ->
        issue =
          issue_for(
            issue_meta,
            meta[:line],
            name,
            "Hardcoded file path. Use Application.get_env/3."
          )

        {value, [issue | issues]}

      name in @size_var_names and large_integer?(value) ->
        issue =
          issue_for(
            issue_meta,
            meta[:line],
            name,
            "Hardcoded size limit. Move to Application config."
          )

        {value, [issue | issues]}

      true ->
        {value, issues}
    end
  end

  defp traverse(ast, issues, _issue_meta), do: {ast, issues}

  defp hardcoded_path?(value) when is_binary(value) do
    String.starts_with?(value, "/") or String.starts_with?(value, "priv/")
  end

  defp hardcoded_path?(_), do: false

  defp large_integer?(value) when is_integer(value), do: value >= 1_000_000
  defp large_integer?(_), do: false

  defp issue_for(issue_meta, line_no, trigger, message) do
    format_issue(
      issue_meta,
      message: message,
      trigger: "#{trigger}",
      line_no: line_no
    )
  end
end
