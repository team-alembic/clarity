defmodule Clarity.Perspective.Registry do
  @moduledoc """
  Discovers and manages lensmakers from application configurations.

  The Registry scans all loaded applications for `:clarity_perspective_lensmakers`
  configuration and creates lenses using the discovered lensmakers. It handles
  the extension system where multiple lensmakers can enhance a single lens.

  ## Configuration

  Lensmaker configuration is managed by `Clarity.Config`. See the documentation
  for `Clarity.Config` for detailed configuration options and examples.

  ## Extension System

  The registry implements a two-phase lens creation:

  1. **Creation Phase**: Calls `make_lens/1` on lensmakers that implement it
  2. **Enhancement Phase**: Calls `update_lens/2` on ALL OTHER lensmakers for each lens

  This allows extensions to enhance base lenses created by other modules.
  """

  alias Clarity.Perspective.Lens

  require Logger

  @type result(type) :: {:ok, type} | {:error, term()}

  @doc """
  Creates lenses from lensmaker modules using the two-phase creation process.

  First calls `make_lens/0` on lensmakers to create base lenses, then calls
  `update_lens/1` on all other lensmakers to allow enhancements.
  """
  @spec get_all_lenses([module()]) :: [Lens.t()]
  def get_all_lenses(lensmakers \\ Clarity.Config.list_lensmakers()) do
    base_lenses =
      lensmakers
      |> Enum.map(&safe_make_lens/1)
      |> Enum.reject(&is_nil/1)

    Enum.map(base_lenses, &enhance_lens(&1, lensmakers))
  end

  @doc """
  Gets a lens by its ID from all discovered lenses.
  """
  @spec get_lens_by_id(String.t()) :: result(Lens.t())
  def get_lens_by_id(lens_id) when is_binary(lens_id) do
    lenses = get_all_lenses()

    case Enum.find(lenses, &(&1.id == lens_id)) do
      nil -> {:error, :lens_not_found}
      lens -> {:ok, lens}
    end
  end

  # Private helper functions

  @spec safe_make_lens(module()) :: Lens.t() | nil
  defp safe_make_lens(lensmaker) do
    case Code.ensure_loaded(lensmaker) do
      {:module, ^lensmaker} ->
        if function_exported?(lensmaker, :make_lens, 0) do
          lensmaker.make_lens()
        end

      _ ->
        nil
    end
  end

  @spec enhance_lens(Lens.t(), [module()]) :: Lens.t()
  defp enhance_lens(%Lens{} = lens, lensmakers) do
    Enum.reduce(lensmakers, lens, &safe_update_lens/2)
  end

  @spec safe_update_lens(module(), Lens.t()) :: Lens.t()
  defp safe_update_lens(lensmaker, %Lens{} = lens) do
    case Code.ensure_loaded(lensmaker) do
      {:module, ^lensmaker} ->
        if function_exported?(lensmaker, :update_lens, 1) do
          lensmaker.update_lens(lens)
        else
          lens
        end

      _ ->
        lens
    end
  end
end
