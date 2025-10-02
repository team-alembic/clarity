defmodule Clarity.Vertex.Util do
  @moduledoc """
  Utility functions for working with vertices.
  """

  @doc """
  Generates a vertex ID from a vertex type module and a list of parts.

  ## Parameters

    * `vertex_type` - The vertex type module (e.g., `Clarity.Vertex.Module`)
    * `parts` - A list of modules, atoms, or strings to include in the ID

  ## Examples

      iex> Clarity.Vertex.Util.id(Clarity.Vertex.Module, [String])
      "module:string"

      iex> Clarity.Vertex.Util.id(Clarity.Vertex.Ash.Resource, [Demo.Accounts.User])
      "ash-resource:demo-accounts-user"

      iex> Clarity.Vertex.Util.id(Clarity.Vertex.Ash.Attribute, [Demo.Accounts.User, :email])
      "ash-attribute:demo-accounts-user:email"

      iex> Clarity.Vertex.Util.id(Clarity.Vertex.Root, ["custom", :part])
      "root:custom:part"

  """
  @spec id(module(), [module() | atom() | String.t()]) :: String.t()
  def id(vertex_type, parts) do
    [vertex_type | parts]
    |> Enum.map(&part_to_string/1)
    |> Enum.map_join(":", &normalize_segment/1)
  end

  @spec part_to_string(atom() | String.t() | integer() | any()) :: String.t()
  defp part_to_string(value)
       when is_atom(value) and not is_boolean(value) and not is_nil(value) do
    case Atom.to_string(value) do
      "Elixir." <> _ ->
        value
        |> module_to_string()
        |> strip_clarity_vertex_prefix()

      string ->
        string
    end
  end

  defp part_to_string(value) when is_binary(value), do: value
  defp part_to_string(value) when is_integer(value), do: Integer.to_string(value)
  defp part_to_string(value), do: value |> :erlang.phash2() |> Integer.to_string()

  @spec module_to_string(module()) :: String.t()
  defp module_to_string(module) do
    Macro.underscore(module)
  end

  @spec strip_clarity_vertex_prefix(String.t()) :: String.t()
  defp strip_clarity_vertex_prefix(string) do
    String.replace_prefix(string, "clarity/vertex/", "")
  end

  @spec normalize_segment(String.t()) :: String.t()
  defp normalize_segment(string) do
    string
    |> String.replace(~r/[^a-zA-Z0-9]+/, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
  end
end
