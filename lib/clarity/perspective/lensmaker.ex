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
  """

  alias Clarity.Perspective.Lens

  @type t() :: module()

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
end
