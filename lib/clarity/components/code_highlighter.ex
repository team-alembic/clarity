defmodule Clarity.Components.CodeHighlighter do
  @moduledoc """
  Provides lexer selection for syntax highlighting using Makeup.
  """

  alias Makeup.Lexers.ElixirLexer

  @doc """
  Gets the appropriate Makeup lexer for a given language string.

  Returns the lexer module or nil if the language is not supported.

  ## Examples

      iex> CodeHighlighter.get_lexer("elixir")
      Makeup.Lexers.ElixirLexer

      iex> CodeHighlighter.get_lexer("python")
      nil

  """
  @spec get_lexer(language :: String.t() | nil) :: module() | nil
  def get_lexer(nil), do: nil
  def get_lexer("elixir"), do: ElixirLexer
  def get_lexer("eex"), do: ElixirLexer
  def get_lexer("heex"), do: ElixirLexer
  def get_lexer("erlang"), do: Makeup.Lexers.ErlangLexer
  def get_lexer(_other), do: nil
end
