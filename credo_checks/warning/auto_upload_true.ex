defmodule CredoChecks.Warning.AutoUploadTrue do
  use Credo.Check,
    base_priority: :normal,
    category: :warning,
    explanations: [
      check: """
      `auto_upload: true` in `allow_upload/3` requires implementing
      `handle_progress/3` callback. Most apps should use manual upload
      with a submit button instead.

      If you intentionally need auto-upload, ensure `handle_progress/3`
      is implemented in the same module.
      """
    ]

  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    source_file
    |> Credo.Code.prewalk(&find_auto_upload(&1, &2, issue_meta))
    |> Enum.reverse()
  end

  defp find_auto_upload({:allow_upload, meta, args} = ast, issues, issue_meta)
       when is_list(args) do
    if has_auto_upload_true?(args) do
      issue =
        format_issue(
          issue_meta,
          message:
            "auto_upload: true requires handle_progress/3. Most apps should use manual upload.",
          trigger: "auto_upload",
          line_no: meta[:line]
        )

      {ast, [issue | issues]}
    else
      {ast, issues}
    end
  end

  defp find_auto_upload(ast, issues, _issue_meta), do: {ast, issues}

  defp has_auto_upload_true?(args) when is_list(args) do
    Enum.any?(args, fn
      {:auto_upload, true} -> true
      list when is_list(list) -> has_auto_upload_true?(list)
      _ -> false
    end)
  end

  defp has_auto_upload_true?(_), do: false
end
