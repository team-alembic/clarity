defmodule Clarity.Resources.AssetPath do
  @moduledoc false

  # Where Clarity.Resources embeds a built asset from, at compile time.
  #
  # Clarity ships its assets built, in priv/static/assets. While developing
  # Clarity itself, the demo app's watchers rebuild them into a separate,
  # gitignored directory (`config :clarity, :assets_path`) so the shipped
  # assets only change on a deliberate `mix assets.deploy`.

  @doc """
  Returns the dev build of `file` in `dev_dir` when there is one, or else
  `shipped`, the built asset in priv.
  """
  @spec pick(Path.t() | nil, String.t(), Path.t()) :: Path.t()
  def pick(nil, _file, shipped), do: shipped

  def pick(dev_dir, file, shipped) do
    dev_path = Path.join(dev_dir, file)
    if File.exists?(dev_path), do: dev_path, else: shipped
  end
end
