defmodule Core.Weather do
  @moduledoc """
  Simple weather client using Open‑Meteo APIs (no API key required).

  - Geocoding: https://geocoding-api.open-meteo.com/v1/search?name=NAME&count=1
  - Forecast:  https://api.open-meteo.com/v1/forecast?latitude=..&longitude=..
  """

  @geocode "https://geocoding-api.open-meteo.com/v1/search"
  @forecast "https://api.open-meteo.com/v1/forecast"

  @doc """
  Fetch current weather and 5-day forecast for a given location name.

  Returns {:ok, map} with keys: :place, :current, :daily
  """
  def fetch(name) when is_binary(name) and name != "" do
    with {:ok, {lat, lon, place}} <- geocode(name),
         {:ok, data} <- get_forecast(lat, lon) do
      {:ok,
       %{
         place: place,
         current: %{
           temperature_c: get_in(data, ["current", "temperature_2m"]) || get_in(data, ["current", "temperature"]),
           weather_code: get_in(data, ["current", "weather_code"])
         },
         daily:
           build_daily(
             data["daily"] || %{},
             get_in(data, ["daily_units"]) || %{}
           )
       }}
    else
      {:error, _} = e -> e
      _ -> {:error, :unknown}
    end
  end

  defp geocode(name) do
    req = Req.new(url: @geocode)
    case Req.get(req, params: [name: name, count: 1]) do
      {:ok, %{status: 200, body: %{"results" => [res | _]}}} ->
        lat = res["latitude"]
        lon = res["longitude"]
        place = %{name: res["name"], country: res["country"], admin1: res["admin1"]}
        {:ok, {lat, lon, place}}
      {:ok, %{status: 200, body: %{"results" => []}}} -> {:error, :not_found}
      {:ok, %{status: s, body: b}} -> {:error, {:http_error, s, b}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_forecast(lat, lon) do
    params = [
      latitude: lat,
      longitude: lon,
      current: "temperature_2m,weather_code",
      daily: "temperature_2m_max,temperature_2m_min,precipitation_sum,weather_code",
      timezone: "auto"
    ]
    req = Req.new(url: @forecast)
    case Req.get(req, params: params) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: s, body: b}} -> {:error, {:http_error, s, b}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_daily(daily, _units) do
    dates = daily["time"] || []
    maxs = daily["temperature_2m_max"] || []
    mins = daily["temperature_2m_min"] || []
    prec = daily["precipitation_sum"] || []
    codes = daily["weather_code"] || []

    Enum.zip([dates, maxs, mins, prec, codes])
    |> Enum.take(5)
    |> Enum.map(fn {d, max, min, p, code} ->
      %{date: d, max_c: max, min_c: min, precipitation_mm: p, weather_code: code}
    end)
  end
end
