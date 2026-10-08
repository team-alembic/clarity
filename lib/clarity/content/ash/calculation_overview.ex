with {:module, Ash} <- Code.ensure_loaded(Ash) do
  defmodule Clarity.Content.Ash.CalculationOverview do
    @moduledoc """
    Content provider for an Ash calculation's overview.

    Leads with the type the calculation returns and how it computes it: its
    expression in full, or the module that implements it. Then its arguments,
    with which are required, and what it loads first.
    """

    @behaviour Clarity.Content

    use Clarity.Web, :live_component

    import Clarity.Components.OverviewComponents
    import Clarity.Content.Ash.Overview

    alias Clarity.Vertex.Ash.Calculation
    alias Clarity.Vertex.Ash.Resource

    @impl Clarity.Content
    def name, do: "Calculation Overview"

    @impl Clarity.Content
    def description, do: "Overview of this Ash calculation"

    @impl Clarity.Content
    def sort_priority, do: -100

    @impl Clarity.Content
    def applies?(%Calculation{}, _lens), do: true
    def applies?(_vertex, _lens), do: false

    @impl Phoenix.LiveComponent
    def update(assigns, socket) do
      %Calculation{calculation: calculation, resource: resource} = assigns.vertex

      {:ok,
       socket
       |> assign(assigns)
       |> assign(
         links: links(assigns),
         calculation: calculation,
         resource: resource,
         expression?: match?({:expr, _code}, computation_of(calculation)),
         loads: loads(calculation)
       )}
    end

    @impl Phoenix.LiveComponent
    def render(assigns) do
      ~H"""
      <div class="ov-page" id={@id}>
        <div class="ov-head">
          <.hero vertex={@vertex} kind="Calculation">
            <:badge :if={@calculation.sensitive?}>
              <.flag kind={:danger}>sensitive</.flag>
            </:badge>
            <:badge>
              <.flag :if={@calculation.public?} kind={:good}>public</.flag>
              <.flag :if={not @calculation.public?} kind={:muted}>private</.flag>
            </:badge>
            <:badge :if={Map.get(@calculation, :async?)}>
              <.flag>async</.flag>
            </:badge>
            <:headline>
              <span class="ov-phrase">
                <.ash_type links={@links} type={@calculation.type} />
                <span class="ov-muted">on</span>
                <.vertex_link links={@links} vertex={%Resource{resource: @resource}} />
                <span class="ov-muted">
                  {if @expression?, do: "by expression", else: "by module"}
                </span>
              </span>
            </:headline>
            <.description links={@links} text={description_of(@calculation)} lead />
          </.hero>

          <.computation calculation={@calculation} full />

          <.facts>
            <:fact :if={@loads != []} label="Loads first">
              <.code_list names={@loads} />
            </:fact>
            <:fact :if={not @calculation.allow_nil?} label="Nil">never</:fact>
            <:fact
              :for={{key, value} <- List.wrap(@calculation.constraints)}
              label={key |> to_string() |> String.replace("_", " ") |> String.capitalize()}
            >
              <code class="ov-code">{inspect(value)}</code>
            </:fact>
            <:fact :if={not @calculation.filterable? or not @calculation.sortable?} label="Queries">
              {[
                if(not @calculation.filterable?, do: "not filterable"),
                if(not @calculation.sortable?, do: "not sortable")
              ]
              |> Enum.reject(&is_nil/1)
              |> Enum.join(", ")}
            </:fact>
          </.facts>
        </div>

        <.section
          :if={@calculation.arguments != []}
          id="arguments"
          title="Arguments"
          icon="attribute"
          tone="data"
          count={length(@calculation.arguments)}
        >
          <.overview_table id="calculation-arguments" rows={@calculation.arguments}>
            <:col :let={argument} label="Name" class="w-0 whitespace-nowrap">
              <span class="ov-link ov-code">
                <.type_icon icon="type" tone="neutral" />{argument.name}
              </span>
            </:col>
            <:col :let={argument} label="Type" class="w-0 whitespace-nowrap">
              <.ash_type links={@links} type={argument.type} />
            </:col>
            <:col :let={argument} label="About">
              <div class="ov-flags">
                <.flag :if={not argument.allow_nil?} kind={:warn}>required</.flag>
                <.flag :if={default(argument)}>default <code>{default(argument)}</code></.flag>
              </div>
              <.description links={@links} text={description_of(argument)} class="mt-0.5" />
            </:col>
          </.overview_table>
        </.section>
      </div>
      """
    end

    # What the calculation loads before it runs, as written.
    @spec loads(Ash.Resource.Calculation.t()) :: [String.t()]
    defp loads(%{load: load}) when load not in [nil, []],
      do: load |> List.wrap() |> Enum.map(&load_name/1)

    defp loads(_calculation), do: []

    @spec load_name(term()) :: String.t()
    defp load_name(name) when is_atom(name), do: Atom.to_string(name)
    defp load_name({name, nested}), do: "#{name}: #{inspect(nested)}"
    defp load_name(other), do: inspect(other)
  end
end
