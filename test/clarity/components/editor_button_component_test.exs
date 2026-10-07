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
        {:editor_not_available,
         "No editor configured - set CLARITY_EDITOR, ELIXIR_EDITOR, or EDITOR environment variable"},
        {{:url, "https://example.com"}, "Open in Browser"},
        {{:execute, fn -> :ok end}, "Open in Editor"}
      ]

      for {action, label} <- cases do
        assert action
               |> render_action()
               |> LazyHTML.query("[aria-label='#{label}'][data-tooltip-text='#{label}']")
               |> Enum.count() == 1,
               "expected #{inspect(action)} to carry #{inspect(label)}"
      end
    end
  end
end
