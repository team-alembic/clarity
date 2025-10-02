defmodule Clarity.Perspective.Lensmaker do
  @moduledoc """
  Behavior for modules that create and update lenses.

  Lensmakers are plugins that can create new lenses or enhance existing ones created
  by other lensmakers. This allows for a composable system where extensions can
  add functionality to base lenses.

  ## Example

      defmodule MyApp.SecurityLensmaker do
        @behaviour Clarity.Perspective.Lensmaker

        alias Clarity.Graph.Filter
        alias Clarity.Perspective.Lens

        @impl Clarity.Perspective.Lensmaker
        def make_lens do
          %Lens{
            id: "security",
            name: "Security Audit",
            description: "Focus on security-related vertices",
            icon: fn -> ~H"🛡️" end,
            filter: Filter.vertex_type([Auth.Module, Permission.Module]),
            intro_vertex: &find_auth_module/1
          }
        end
      end

  ## Extension Example

      defmodule MyApp.SecurityReportExtension do
        @behaviour Clarity.Perspective.Lensmaker

        @impl Clarity.Perspective.Lensmaker
        def update_lens(%{id: "security"} = lens) do
          # Example: Could modify the lens's content sorter or other properties
          lens
        end

        def update_lens(lens), do: lens
      end

  ## Configuration

  Register lensmakers in your application configuration:

      config :my_app, :clarity_perspective_lensmakers, [
        MyApp.SecurityLensmaker,
        MyApp.SecurityReportExtension
      ]

  ## Two-Phase Lens Creation

  1. **Creation Phase**: Calls `make_lens/0` on lensmakers that implement it
  2. **Enhancement Phase**: Calls `update_lens/1` on all lensmakers for each lens

  This allows extensions to enhance base lenses created by other modules.
  """

  alias Clarity.Perspective.Lens

  @type t() :: module()
  @type result(type) :: {:ok, type} | {:error, term()}

  @doc """
  Creates a new lens.
  """
  @callback make_lens() :: Lens.t()

  @doc """
  Updates an existing lens, potentially enhancing it with additional functionality.

  Extensions typically check the lens ID and only modify lenses they are designed to enhance.
  """
  @callback update_lens(lens :: Lens.t()) :: Lens.t()

  @optional_callbacks [make_lens: 0, update_lens: 1]

  @doc false
  @spec get_all_lenses([module()]) :: [Lens.t()]
  def get_all_lenses(lensmakers \\ Clarity.Config.list_lensmakers()) do
    base_lenses =
      lensmakers
      |> Enum.map(&safe_make_lens/1)
      |> Enum.reject(&is_nil/1)

    Enum.map(base_lenses, &enhance_lens(&1, lensmakers))
  end

  @doc false
  @spec get_lens_by_id(String.t()) :: result(Lens.t())
  def get_lens_by_id(lens_id) when is_binary(lens_id) do
    lenses = get_all_lenses()

    case Enum.find(lenses, &(&1.id == lens_id)) do
      nil -> {:error, :lens_not_found}
      lens -> {:ok, lens}
    end
  end

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
