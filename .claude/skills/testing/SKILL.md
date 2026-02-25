---
name: testing
description: Use when writing or modifying ExUnit tests, test helpers, fixtures, or discussing testing strategy. Invoke BEFORE writing tests.
file_patterns:
  - "**/*_test.exs"
  - "**/test/**"
  - "**/test_helper.exs"
  - "**/support/**"
auto_suggest: true
---

# Testing Essentials

## Test Module Types

| Module | Use For | DB? | Async? |
|--------|---------|-----|--------|
| `DataCase` | Context/schema tests | Yes | Yes (sandbox) |
| `ConnCase` | Controller/LiveView tests | Yes | Yes (sandbox) |
| (none) | Pure function tests | No | Yes |

## TDD Workflow

1. Write failing test
2. Write minimum code to pass
3. Refactor
4. Repeat

## Rules

1. **`DataCase` for DB tests, `ConnCase` for LiveView/controller**
2. **Test happy path AND error paths**
3. **`async: true`** unless tests share mutable state
4. **Fixtures in `test/support/`** -- reusable factory functions
5. **`has_element?/element` for LiveView assertions** -- not string matching on HTML
6. **Always test unauthorized access** -- verify auth guards work
7. **Test public context interface** -- not internal functions
8. **Use `describe` blocks** to group related tests

## Fixture Pattern

```elixir
# test/support/fixtures/accounts_fixtures.ex
defmodule MyApp.AccountsFixtures do
  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{
        name: "Test User",
        email: "user-#{System.unique_integer()}@example.com"
      })
      |> MyApp.Accounts.create_user()

    user
  end
end
```

## Context Tests

```elixir
defmodule MyApp.AccountsTest do
  use MyApp.DataCase, async: true

  alias MyApp.Accounts

  describe "create_user/1" do
    test "valid attrs creates user" do
      assert {:ok, user} = Accounts.create_user(%{name: "Jo", email: "jo@test.com"})
      assert user.name == "Jo"
    end

    test "invalid attrs returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Accounts.create_user(%{})
    end

    test "duplicate email returns error" do
      user_fixture(email: "dup@test.com")
      assert {:error, changeset} = Accounts.create_user(%{name: "X", email: "dup@test.com"})
      assert %{email: ["has already been taken"]} = errors_on(changeset)
    end
  end
end
```

## LiveView Tests

```elixir
defmodule MyAppWeb.UserLiveTest do
  use MyAppWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "index" do
    test "lists users", %{conn: conn} do
      user = user_fixture()
      {:ok, view, html} = live(conn, ~p"/users")
      assert html =~ user.name
      assert has_element?(view, "#user-#{user.id}")
    end

    test "creates user", %{conn: conn} do
      {:ok, view, _} = live(conn, ~p"/users/new")

      view
      |> form("#user-form", user: %{name: "New User", email: "new@test.com"})
      |> render_submit()

      assert_redirect(view, ~p"/users")
    end

    test "handles errors", %{conn: conn} do
      {:ok, view, _} = live(conn, ~p"/users/new")

      html =
        view
        |> form("#user-form", user: %{name: "", email: ""})
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end
  end
end
```

## Changeset Tests

```elixir
describe "user changeset" do
  test "valid changeset" do
    changeset = User.changeset(%User{}, %{name: "Jo", email: "jo@test.com"})
    assert changeset.valid?
  end

  test "requires email" do
    changeset = User.changeset(%User{}, %{name: "Jo"})
    assert %{email: ["can't be blank"]} = errors_on(changeset)
  end
end
```

## LiveView Upload Tests

```elixir
test "uploads file", %{conn: conn} do
  {:ok, view, _} = live(conn, ~p"/upload")

  avatar =
    file_input(view, "#upload-form", :avatar, [
      %{name: "photo.jpg", content: File.read!("test/fixtures/photo.jpg"), type: "image/jpeg"}
    ])

  assert render_upload(avatar, "photo.jpg") =~ "photo.jpg"

  view
  |> form("#upload-form")
  |> render_submit()

  assert_redirect(view)
end
```

## Common Assertions

| Assertion | Use For |
|-----------|---------|
| `assert html =~ "text"` | Text presence in rendered HTML |
| `has_element?(view, selector)` | DOM element exists |
| `has_element?(view, selector, text)` | Element with specific text |
| `element(view, selector) \|> render_click()` | Click and get result |
| `assert_redirect(view, path)` | Navigation happened |
| `assert_patch(view, path)` | Patch navigation happened |
| `assert_push_event(view, event, payload)` | JS event pushed |
| `refute has_element?(view, selector)` | Element does NOT exist |

## Testing PubSub

```elixir
test "broadcasts on create" do
  Phoenix.PubSub.subscribe(MyApp.PubSub, "items")
  {:ok, item} = Items.create_item(%{name: "test"})
  assert_receive {:item_created, ^item}
end
```

## Tips

- Use `errors_on/1` helper from DataCase for changeset error assertions
- `render_hook(view, event, params)` for testing JS hook interactions
- `assert_patch` for same-LiveView URL changes
- Set `@tag :capture_log` to suppress expected log output in tests
- Use `Mox` for external service mocks -- define behaviours, mock in tests
