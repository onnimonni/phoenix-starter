defmodule CredoChecks.Warning.StringConcatInEnum do
  use Credo.Check,
    base_priority: :normal,
    category: :warning,
    explanations: [
      check: """
      String concatenation (`<>`) inside Enum callbacks is inefficient.
      Each concatenation creates a new binary.

      Use IO lists or `Enum.join/2` instead.
      """
    ]

  @enum_fns ~w(map reduce each filter flat_map map_reduce)a

  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    source_file
    |> Credo.Code.prewalk(&traverse(&1, &2, issue_meta))
    |> Enum.reverse()
  end

  # Match Enum.map(list, fn ... <> ... end)
  defp traverse(
         {{:., _, [{:__aliases__, _, [:Enum]}, func_name]}, meta, args},
         issues,
         issue_meta
       )
       when func_name in @enum_fns do
    ast = {{:., meta, [{:__aliases__, meta, [:Enum]}, func_name]}, meta, args}

    if has_concat_in_callback?(args) do
      issue =
        issue_for(
          issue_meta,
          meta[:line],
          "Enum.#{func_name}",
          "String <> in Enum.#{func_name} callback. Use IO lists or Enum.join."
        )

      {ast, [issue | issues]}
    else
      {ast, issues}
    end
  end

  defp traverse(ast, issues, _issue_meta), do: {ast, issues}

  defp has_concat_in_callback?(args) when is_list(args) do
    args
    |> Enum.any?(fn
      {:fn, _, _} = fn_ast -> contains_concat?(fn_ast)
      _ -> false
    end)
  end

  defp has_concat_in_callback?(_), do: false

  defp contains_concat?({:<>, _, _}), do: true

  defp contains_concat?({_, _, children}) when is_list(children) do
    Enum.any?(children, &contains_concat?/1)
  end

  defp contains_concat?(list) when is_list(list) do
    Enum.any?(list, &contains_concat?/1)
  end

  defp contains_concat?({left, right}) do
    contains_concat?(left) or contains_concat?(right)
  end

  defp contains_concat?(_), do: false

  defp issue_for(issue_meta, line_no, trigger, message) do
    format_issue(
      issue_meta,
      message: message,
      trigger: trigger,
      line_no: line_no
    )
  end
end
