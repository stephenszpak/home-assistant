defmodule Core.Home do
  @moduledoc """
  Home Assistant helper functions (stubs).
  """

  require Logger

  def config do
    %{
      base: Application.get_env(:core, :ha_base_url),
      token: Application.get_env(:core, :ha_token)
    }
  end

  @doc """
  Toggle an entity via Home Assistant REST API (stub).
  """
  def toggle(_entity_id) do
    if missing?() do
      Logger.warning("HA config missing; not calling Home Assistant")
      {:error, :not_configured}
    else
      {:ok, :stub}
    end
  end

  defp missing? do
    cfg = config()
    is_nil(cfg.base) or cfg.base == "" or is_nil(cfg.token) or cfg.token == ""
  end
end

