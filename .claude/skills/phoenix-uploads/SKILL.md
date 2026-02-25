---
name: phoenix-uploads
description: Use when implementing file uploads in Phoenix LiveView. Covers manual/auto upload, static paths, storage, security.
file_patterns:
  - "**/*upload*"
  - "**/*_live.ex"
auto_suggest: true
---

# Phoenix Uploads

## Rules

1. **Manual uploads, not `auto_upload: true`** -- auto requires `handle_progress/3` and is error-prone
2. **Add upload dir to `static_paths()`** -- or files won't serve in production
3. **Handle upload errors** -- always implement `error_to_string/1`
4. **`mkdir_p` before saving** -- directory may not exist
5. **Unique filenames** -- prevent overwrites and path traversal
6. **Validate file types server-side** -- client `content_type` is untrusted
7. **Restart server after `static_paths()` changes** -- cached at compile time

## Upload Configuration

```elixir
@impl true
def mount(_params, _session, socket) do
  {:ok,
   socket
   |> assign(:uploaded_files, [])
   |> allow_upload(:avatar,
     accept: ~w(.jpg .jpeg .png .webp),
     max_entries: 1,
     max_file_size: 5_000_000  # 5 MB -- move to config for production!
   )}
end
```

## Complete Upload Pattern

```elixir
@impl true
def handle_event("save", _params, socket) do
  uploaded_files =
    consume_uploaded_entries(socket, :avatar, fn %{path: path}, entry ->
      filename = unique_filename(entry)
      dest = Path.join(upload_dir(), filename)
      File.mkdir_p!(Path.dirname(dest))
      File.cp!(path, dest)
      {:ok, ~p"/uploads/#{filename}"}
    end)

  {:noreply, update(socket, :uploaded_files, &(&1 ++ uploaded_files))}
end

defp unique_filename(entry) do
  ext = Path.extname(entry.client_name)
  "#{entry.uuid}#{ext}"
end

defp upload_dir do
  Application.get_env(:my_app, :upload_dir, "priv/static/uploads")
end
```

## Template

```heex
<.form for={%{}} phx-submit="save" phx-change="validate">
  <.live_file_input upload={@uploads.avatar} />

  <%= for entry <- @uploads.avatar.entries do %>
    <.live_img_preview entry={entry} width="150" />
    <button type="button" phx-click="cancel-upload" phx-value-ref={entry.ref}>
      Cancel
    </button>
    <%= for err <- upload_errors(@uploads.avatar, entry) do %>
      <p class="text-red-500"><%= error_to_string(err) %></p>
    <% end %>
  <% end %>

  <button type="submit">Upload</button>
</.form>
```

## Error Handling

```elixir
defp error_to_string(:too_large), do: "File too large"
defp error_to_string(:too_many_files), do: "Too many files"
defp error_to_string(:not_accepted), do: "Unacceptable file type"
defp error_to_string(err), do: "Error: #{inspect(err)}"
```

## Static Paths Configuration

```elixir
# In your_app_web.ex
def static_paths, do: ~w(assets fonts images uploads favicon.ico robots.txt)

# In endpoint.ex
plug Plug.Static,
  at: "/",
  from: :my_app,
  gzip: false,
  only: MyAppWeb.static_paths()
```

## External Storage (S3)

For production, use presigned URLs:

```elixir
allow_upload(:avatar,
  accept: ~w(.jpg .png),
  max_entries: 1,
  external: &presign_upload/2
)

defp presign_upload(entry, socket) do
  config = Application.get_env(:my_app, :s3)
  key = "uploads/#{entry.uuid}-#{entry.client_name}"
  {:ok, %{uploader: "S3", key: key, url: presigned_url(config, key)}, socket}
end
```

## Security

- **Path traversal**: Use `entry.uuid` for filenames, never raw `client_name`
- **Content-type**: Validate with magic bytes, not client-provided MIME type
- **Size limits**: Move to `Application.get_env/3`, not hardcoded
- **Content-Disposition**: Set `attachment` header when serving user-uploaded files
- **Virus scanning**: Consider ClamAV for user uploads in production

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| 404 on uploaded file | Not in `static_paths()` | Add `"uploads"` to `static_paths/0` |
| Files disappear on deploy | Stored in `priv/static/` | Use external storage or persistent volume |
| Upload works in dev, not prod | `static_paths` caching | Restart server after changes |
