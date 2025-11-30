defmodule Clarity.IconComponents do
  @moduledoc """
  Provides reusable icon components for the Clarity application.

  All icons are prefixed with `icon_` and accept a `class` attribute for custom styling.
  """

  use Phoenix.Component

  alias Phoenix.LiveView.Rendered
  alias Phoenix.LiveView.Socket

  embed_templates "icon_components/*"

  @doc """
  Renders an info icon (circle with i).
  """
  attr :class, :any, default: "", doc: "CSS classes to apply to the icon"
  attr :rest, :global, doc: "Additional HTML attributes"

  @spec icon_info(assigns :: Socket.assigns()) :: Rendered.t()
  def icon_info(assigns)

  @doc """
  Renders a success icon (circle with checkmark).
  """
  attr :class, :any, default: "", doc: "CSS classes to apply to the icon"
  attr :rest, :global, doc: "Additional HTML attributes"

  @spec icon_success(assigns :: Socket.assigns()) :: Rendered.t()
  def icon_success(assigns)

  @doc """
  Renders an error icon (circle with exclamation mark).
  """
  attr :class, :any, default: "", doc: "CSS classes to apply to the icon"
  attr :rest, :global, doc: "Additional HTML attributes"

  @spec icon_error(assigns :: Socket.assigns()) :: Rendered.t()
  def icon_error(assigns)

  @doc """
  Renders a warning icon (triangle with exclamation).
  """
  attr :class, :any, default: "", doc: "CSS classes to apply to the icon"
  attr :rest, :global, doc: "Additional HTML attributes"

  @spec icon_warning(assigns :: Socket.assigns()) :: Rendered.t()
  def icon_warning(assigns)

  @doc """
  Renders a close icon (X symbol).
  """
  attr :class, :any, default: "", doc: "CSS classes to apply to the icon"
  attr :rest, :global, doc: "Additional HTML attributes"

  @spec icon_close(assigns :: Socket.assigns()) :: Rendered.t()
  def icon_close(assigns)

  @doc """
  Renders a menu icon (hamburger menu).
  """
  attr :class, :any, default: "", doc: "CSS classes to apply to the icon"
  attr :rest, :global, doc: "Additional HTML attributes"

  @spec icon_menu(assigns :: Socket.assigns()) :: Rendered.t()
  def icon_menu(assigns)

  @doc """
  Renders a spinner icon (loading animation).
  """
  attr :class, :any, default: "", doc: "CSS classes to apply to the icon"
  attr :rest, :global, doc: "Additional HTML attributes"

  @spec icon_spinner(assigns :: Socket.assigns()) :: Rendered.t()
  def icon_spinner(assigns)

  @doc """
  Renders a sun icon (theme toggle).
  """
  attr :class, :any, default: "", doc: "CSS classes to apply to the icon"
  attr :rest, :global, doc: "Additional HTML attributes"

  @spec icon_sun(assigns :: Socket.assigns()) :: Rendered.t()
  def icon_sun(assigns)

  @doc """
  Renders a moon icon (theme toggle).
  """
  attr :class, :any, default: "", doc: "CSS classes to apply to the icon"
  attr :rest, :global, doc: "Additional HTML attributes"

  @spec icon_moon(assigns :: Socket.assigns()) :: Rendered.t()
  def icon_moon(assigns)

  @doc """
  Renders an aperture icon (camera aperture).
  """
  attr :class, :any, default: "", doc: "CSS classes to apply to the icon"
  attr :rest, :global, doc: "Additional HTML attributes"

  @spec icon_aperture(assigns :: Socket.assigns()) :: Rendered.t()
  def icon_aperture(assigns)

  @doc """
  Renders a chevron down icon (dropdown arrow).
  """
  attr :class, :any, default: "", doc: "CSS classes to apply to the icon"
  attr :rest, :global, doc: "Additional HTML attributes"

  @spec icon_chevron_down(assigns :: Socket.assigns()) :: Rendered.t()
  def icon_chevron_down(assigns)

  @doc """
  Renders a check icon (checkmark).
  """
  attr :class, :any, default: "", doc: "CSS classes to apply to the icon"
  attr :rest, :global, doc: "Additional HTML attributes"

  @spec icon_check(assigns :: Socket.assigns()) :: Rendered.t()
  def icon_check(assigns)

  @doc """
  Renders a refresh icon (circular arrows).
  """
  attr :class, :any, default: "", doc: "CSS classes to apply to the icon"
  attr :rest, :global, doc: "Additional HTML attributes"

  @spec icon_refresh(assigns :: Socket.assigns()) :: Rendered.t()
  def icon_refresh(assigns)

  @doc """
  Renders a sliders icon (adjustments/settings).
  """
  attr :class, :any, default: "", doc: "CSS classes to apply to the icon"
  attr :rest, :global, doc: "Additional HTML attributes"

  @spec icon_sliders(assigns :: Socket.assigns()) :: Rendered.t()
  def icon_sliders(assigns)

  @doc """
  Renders an external link icon (arrow out of box).
  """
  attr :class, :any, default: "", doc: "CSS classes to apply to the icon"
  attr :rest, :global, doc: "Additional HTML attributes"

  @spec icon_external_link(assigns :: Socket.assigns()) :: Rendered.t()
  def icon_external_link(assigns)

  @doc """
  Renders a clipboard icon (copy to clipboard).
  """
  attr :class, :any, default: "", doc: "CSS classes to apply to the icon"
  attr :rest, :global, doc: "Additional HTML attributes"

  @spec icon_clipboard(assigns :: Socket.assigns()) :: Rendered.t()
  def icon_clipboard(assigns)

  @doc """
  Renders a code icon (source code brackets).
  """
  attr :class, :any, default: "", doc: "CSS classes to apply to the icon"
  attr :rest, :global, doc: "Additional HTML attributes"

  @spec icon_code(assigns :: Socket.assigns()) :: Rendered.t()
  def icon_code(assigns)
end
