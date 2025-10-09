defmodule UiWeb.WeatherComponents do
  use Phoenix.Component

  attr :place, :map, required: true
  attr :current, :map, required: true
  attr :daily, :list, default: []
  def panel(assigns) do
    ~H"""
    <div class="rounded-2xl bg-white shadow p-4 text-gray-800">
      <div class="flex items-center justify-between">
        <div>
          <div class="text-sm text-gray-500"><%= place_label(@place) %></div>
          <div class="text-2xl font-semibold"><%= round(@current.temperature_c) %>°C</div>
          <div class="text-xs text-gray-500"><%= code_desc(@current.weather_code) %></div>
        </div>
      </div>
      <div class="mt-3 grid grid-cols-5 gap-2 text-center text-xs">
        <%= for d <- @daily do %>
          <div class="rounded-xl bg-gray-100 p-2">
            <div><%= short_date(d.date) %></div>
            <div class="font-medium"><%= round(d.max_c) %>° / <%= round(d.min_c) %>°</div>
            <div class="text-gray-500"><%= code_emoji(d.weather_code) %></div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp place_label(%{name: n, admin1: a, country: c}) do
    [n, a, c] |> Enum.reject(&is_nil/1) |> Enum.join(", ")
  end

  defp short_date(d) do
    d
  end

  defp code_desc(nil), do: ""
  defp code_desc(code) do
    case code do
      0 -> "Clear"
      1 -> "Mainly clear"
      2 -> "Partly cloudy"
      3 -> "Overcast"
      45 -> "Fog"
      48 -> "Rime fog"
      51 -> "Drizzle"
      61 -> "Rain"
      71 -> "Snow"
      80 -> "Showers"
      95 -> "Thunderstorm"
      _ -> "Weather"
    end
  end

  defp code_emoji(nil), do: ""
  defp code_emoji(code) do
    case code do
      0 -> "☀️"
      1 -> "🌤️"
      2 -> "⛅"
      3 -> "☁️"
      45 -> "🌫️"
      48 -> "🌫️"
      51 -> "🌦️"
      61 -> "🌧️"
      71 -> "🌨️"
      80 -> "🌦️"
      95 -> "⛈️"
      _ -> "🌡️"
    end
  end
end

