defmodule CredoChecks.Warning.DeprecatedPhoenixPattern do
  use Credo.Check,
    base_priority: :high,
    category: :warning,
    explanations: [
      check: """
      Detects deprecated Phoenix patterns:

      - `form_for/3,4` -- use `<.form for={to_form(@changeset)}>` instead
      - `live_redirect/2` -- use `<.link navigate={path}>` instead
      - `live_patch/2` -- use `<.link patch={path}>` instead
      """
    ]

  @deprecated_fns %{
    :form_for => "form_for is deprecated. Use <.form for={to_form(@changeset)}>.",
    :live_redirect => "live_redirect is deprecated. Use <.link navigate={path}>.",
    :live_patch => "live_patch is deprecated. Use <.link patch={path}>."
  }

  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    source_file
    |> Credo.Code.prewalk(&traverse(&1, &2, issue_meta))
    |> Enum.reverse()
  end

  defp traverse({name, meta, args}, issues, issue_meta)
       when is_atom(name) and is_list(args) and is_map_key(@deprecated_fns, name) do
    message = @deprecated_fns[name]
    issue = issue_for(issue_meta, meta[:line], name, message)
    {{name, meta, args}, [issue | issues]}
  end

  defp traverse(ast, issues, _issue_meta), do: {ast, issues}

  defp issue_for(issue_meta, line_no, trigger, message) do
    format_issue(
      issue_meta,
      message: message,
      trigger: "#{trigger}",
      line_no: line_no
    )
  end
end
