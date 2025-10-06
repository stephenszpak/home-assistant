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
  Toggle an entity via Home Assistant REST API.

  POST {base}/api/services/homeassistant/toggle with JSON body %{entity_id: id}
  Requires `HA_TOKEN` in env; returns {:ok, body} | {:error, reason}
  """
  def toggle(entity_id) when is_binary(entity_id) do
    case config() do
      %{base: base, token: token} when is_binary(base) and base != "" and is_binary(token) and token != "" ->
        url = URI.merge(base, "/api/services/homeassistant/toggle") |> to_string()
        headers = [{"authorization", "Bearer #{token}"}, {"content-type", "application/json"}]
        body = %{entity_id: entity_id}
        req = Req.new(url: url, headers: headers, finch: Core.Finch)
        case Req.post(req, json: body) do
          {:ok, %{status: status, body: resp}} when status in 200..299 -> {:ok, resp}
          {:ok, %{status: status, body: resp}} -> {:error, {:http_error, status, resp}}
          {:error, reason} -> {:error, reason}
        end

      _ ->
        Logger.warning("HA config missing; not calling Home Assistant")
        {:error, :not_configured}
    end
  end

  # no-op
end
