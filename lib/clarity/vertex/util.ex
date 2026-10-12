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
    Enum.map_join([vertex_type | parts], ":", &segment/1)
  end

  @segment_cache __MODULE__

  @doc false
  # Atoms' segments, most of every id, are worked out once and kept here: ids
  # are needed all the time, to look up a vertex given its struct, and working
  # out a module's takes a while.
  @spec create_segment_cache() :: :ets.table()
  def create_segment_cache do
    :ets.new(@segment_cache, [
      :named_table,
      :public,
      :set,
      read_concurrency: true,
      write_concurrency: true
    ])
  end

  @spec segment(atom() | String.t() | integer() | term()) :: String.t()
  defp segment(value) when is_atom(value) and not is_boolean(value) and not is_nil(value) do
    case :ets.whereis(@segment_cache) do
      :undefined -> atom_segment(value)
      table -> cached_atom_segment(table, value)
    end
  end

  defp segment(value) when is_binary(value), do: normalize_segment(value)
  defp segment(value) when is_integer(value), do: Integer.to_string(value)
  defp segment(value), do: value |> :erlang.phash2() |> Integer.to_string()

  @spec cached_atom_segment(:ets.table(), atom()) :: String.t()
  defp cached_atom_segment(table, atom) do
    case :ets.lookup_element(table, atom, 2, nil) do
      nil ->
        segment = atom_segment(atom)
        :ets.insert(table, {atom, segment})
        segment

      segment ->
        segment
    end
  end

  @spec atom_segment(atom()) :: String.t()
  defp atom_segment(atom) do
    case Atom.to_string(atom) do
      "Elixir." <> _ ->
        atom
        |> Macro.underscore()
        |> String.replace_prefix("clarity/vertex/", "")
        |> normalize_segment()

      string ->
        normalize_segment(string)
    end
  end

  # Runs of anything but ASCII letters and digits become one dash, and none
  # is left at either end.
  @spec normalize_segment(String.t()) :: String.t()
  defp normalize_segment(string), do: normalize_segment(string, <<>>, false)

  @spec normalize_segment(binary(), binary(), boolean()) :: String.t()
  defp normalize_segment(<<char, rest::binary>>, acc, dash?)
       when char in ?a..?z or char in ?A..?Z or char in ?0..?9 do
    acc = if dash? and acc != <<>>, do: <<acc::binary, ?->>, else: acc
    normalize_segment(rest, <<acc::binary, char>>, false)
  end

  defp normalize_segment(<<_char, rest::binary>>, acc, _dash?),
    do: normalize_segment(rest, acc, true)

  defp normalize_segment(<<>>, acc, _dash?), do: acc
end
