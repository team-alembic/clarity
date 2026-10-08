defmodule Clarity.EditorButtonComponentTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias Clarity.EditorButtonComponent

  @spec render_action(term()) :: LazyHTML.t()
  defp render_action(editor_action) do
    %{editor_action: editor_action, myself: nil, __changed__: nil}
    |> EditorButtonComponent.render()
    |> rendered_to_string()
    |> LazyHTML.from_fragment()
  end

  describe "icon-only actions" do
    test "keep an accessible name and gain a hover hint" do
      cases = [
        {:editor_not_available, "Open in editor", "No editor configured: set CLARITY_EDITOR, ELIXIR_EDITOR or EDITOR"},
        {{:url, "https://example.com"}, "View source online", "View source online"},
        {{:execute, fn -> :ok end}, "Open in editor", "Open in editor"}
      ]

      for {action, name, hint} <- cases do
        assert action
               |> render_action()
               |> LazyHTML.query(".icon-button[aria-label='#{name}'][data-tooltip-text='#{hint}']")
               |> Enum.count() == 1,
               "expected #{inspect(action)} to be named #{inspect(name)} with hint #{inspect(hint)}"
      end
    end

    test "without an editor, stay hoverable so the hint can say why, but do nothing" do
      button = :editor_not_available |> render_action() |> LazyHTML.query("button.icon-button")

      assert LazyHTML.attribute(button, "aria-disabled") == ["true"]
      assert LazyHTML.attribute(button, "disabled") == []
      assert LazyHTML.attribute(button, "phx-click") == []
    end
  end
end
