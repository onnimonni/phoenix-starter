defmodule CredoChecks.Warning.MissingImplAnnotation do
  use Credo.Check,
    base_priority: :high,
    category: :warning,
    explanations: [
      check: """
      Callback functions (mount, handle_event, handle_info, handle_call,
      handle_cast, render, init, terminate) should be preceded by `@impl true`.

      This makes it explicit which functions are behaviour callbacks and helps
      the compiler catch mistakes.
      """
    ]

  @callback_names ~w(mount handle_event handle_info handle_call handle_cast render init terminate)a

  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    source_file
    |> Credo.Code.prewalk(&traverse(&1, &2, issue_meta))
    |> Enum.reverse()
  end

  defp traverse({:defmodule, _, _} = ast, issues, issue_meta) do
    module_issues = check_module(ast, issue_meta)
    {ast, module_issues ++ issues}
  end

  defp traverse(ast, issues, _issue_meta), do: {ast, issues}

  defp check_module({:defmodule, _, [_name, [do: {:__block__, _, body}]]}, issue_meta) do
    check_body(body, issue_meta)
  end

  defp check_module({:defmodule, _, [_name, [do: single]]}, issue_meta) do
    check_body([single], issue_meta)
  end

  defp check_module(_, _issue_meta), do: []

  defp check_body(body, issue_meta) when is_list(body) do
    body
    |> Enum.chunk_every(2, 1)
    |> Enum.reduce([], fn
      [{:@, _, [{:impl, _, _}]}, _next | _], acc ->
        acc

      [_prev, {:def, meta, [{name, _, _args} | _]} | _], acc when name in @callback_names ->
        [issue_for(issue_meta, meta[:line], name) | acc]

      [{:def, meta, [{name, _, _args} | _]}], acc when name in @callback_names ->
        # First element in module body is a callback without @impl
        [issue_for(issue_meta, meta[:line], name) | acc]

      _, acc ->
        acc
    end)
  end

  defp check_body(_, _issue_meta), do: []

  defp issue_for(issue_meta, line_no, trigger) do
    format_issue(
      issue_meta,
      message: "Missing @impl true before callback `#{trigger}`.",
      trigger: "#{trigger}",
      line_no: line_no
    )
  end
end
