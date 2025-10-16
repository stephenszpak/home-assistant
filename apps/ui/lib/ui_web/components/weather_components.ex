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

  # Polished tile used on Home clock
  attr :weather, :map, required: true
  attr :id, :string, default: "weather-tile"
  def tile(assigns) do
    w = assigns.weather
    today = Enum.at(w[:daily] || [], 0) || %{}
    assigns = assigns |> Map.put(:w, w) |> Map.put(:today, today)
    ~H"""
    <div id={@id} class="w-full max-w-md text-right select-none" phx-update="ignore">
      <div class="inline-flex items-center justify-end gap-3" data-cycle>
        <.wx_icon code={@w.current[:weather_code] || @today[:weather_code]} />
        <div>
          <div class="text-5xl md:text-6xl font-semibold leading-none [font-variant-numeric:tabular-nums]">
            <%= temp_f(@w.current[:temperature_c]) %>
          </div>
          <div class="mt-0.5 text-base md:text-lg text-neutral-700 dark:text-neutral-200"><%= code_desc(@w.current[:weather_code] || @today[:weather_code]) %></div>
          <div class="mt-0.5 text-sm md:text-base text-neutral-500 dark:text-neutral-400">
            <%= case @today do %>
              <% %{max_c: maxc, min_c: minc} when is_number(maxc) and is_number(minc) -> %>
                H <%= round(to_f(maxc)) %>° • L <%= round(to_f(minc)) %>°
              <% _ -> %>
                &nbsp;
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp temp_f(nil), do: "—"
  defp temp_f(c) when is_number(c), do: Integer.to_string(round(to_f(c))) <> "°F"
  defp to_f(c), do: c * 9 / 5 + 32

  # Tailwind/Heroicons-style inline SVG weather icon
  attr :code, :integer, default: nil
  def wx_icon(assigns) do
    ~H"""
    <%= case coarse(@code) do %>
      <% :clear -> %>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class="h-12 w-12 md:h-14 md:w-14 text-yellow-400" aria-hidden="true">
          <circle cx="12" cy="12" r="4" fill="currentColor"/>
          <g stroke="currentColor" stroke-linecap="round">
            <line x1="12" y1="2.5" x2="12" y2="5"/>
            <line x1="12" y1="19" x2="12" y2="21.5"/>
            <line x1="2.5" y1="12" x2="5" y2="12"/>
            <line x1="19" y1="12" x2="21.5" y2="12"/>
            <line x1="5.2" y1="5.2" x2="6.9" y2="6.9"/>
            <line x1="17.1" y1="17.1" x2="18.8" y2="18.8"/>
            <line x1="5.2" y1="18.8" x2="6.9" y2="17.1"/>
            <line x1="17.1" y1="6.9" x2="18.8" y2="5.2"/>
          </g>
        </svg>
      <% :cloud -> %>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class="h-12 w-12 md:h-14 md:w-14 text-gray-400 dark:text-gray-300" aria-hidden="true">
          <path d="M7 18h9a4 4 0 0 0 0-8 6 6 0 0 0-11.3 1.8A3.5 3.5 0 0 0 7 18Z" fill="currentColor"/>
        </svg>
      <% :rain -> %>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class="h-12 w-12 md:h-14 md:w-14" aria-hidden="true">
          <path d="M7 16h9a4 4 0 0 0 0-8 6 6 0 0 0-11.3 1.8A3.5 3.5 0 0 0 7 16Z" fill="currentColor" class="text-gray-400 dark:text-gray-300"/>
          <g stroke="currentColor" stroke-linecap="round" class="text-blue-500">
            <line x1="8" y1="18" x2="7" y2="21"/>
            <line x1="12" y1="18" x2="11" y2="21"/>
            <line x1="16" y1="18" x2="15" y2="21"/>
          </g>
        </svg>
      <% :storm -> %>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class="h-12 w-12 md:h-14 md:w-14" aria-hidden="true">
          <path d="M7 15h9a4 4 0 0 0 0-8 6 6 0 0 0-11.3 1.8A3.5 3.5 0 0 0 7 15Z" fill="currentColor" class="text-gray-400 dark:text-gray-300"/>
          <path d="M11 16l-2 5 5-4-2 5" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" class="text-yellow-400"/>
        </svg>
      <% :snow -> %>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class="h-12 w-12 md:h-14 md:w-14 text-sky-400" aria-hidden="true">
          <path d="M12 3v18M3 12h18M5 7l14 10M5 17L19 7" stroke="currentColor" stroke-width="1.2" fill="none" stroke-linecap="round"/>
        </svg>
      <% _ -> %>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class="h-12 w-12 md:h-14 md:w-14 text-gray-400 dark:text-gray-300" aria-hidden="true">
          <path d="M7 18h9a4 4 0 0 0 0-8 6 6 0 0 0-11.3 1.8A3.5 3.5 0 0 0 7 18Z" fill="currentColor"/>
        </svg>
    <% end %>
    """
  end

  # Simple inline icon set (legible in dark/light)
  attr :code, :integer, default: nil
  attr :class, :string, default: "h-10 w-10"
  def icon(assigns) do
    ~H"""
    <%= case coarse(@code) do %>
      <% :clear -> %>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class={@class} fill="currentColor" aria-hidden="true"><circle cx="12" cy="12" r="6"/></svg>
      <% :cloud -> %>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class={@class} fill="currentColor" aria-hidden="true"><path d="M7 18h9a4 4 0 0 0 0-8 6 6 0 0 0-11.3 1.8A3.5 3.5 0 0 0 7 18Z"/></svg>
      <% :rain -> %>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class={@class} fill="currentColor" aria-hidden="true"><path d="M7 16h9a4 4 0 0 0 0-8 6 6 0 0 0-11.3 1.8A3.5 3.5 0 0 0 7 16Z"/><path d="M8 18l-1 3M12 18l-1 3M16 18l-1 3" stroke="currentColor" stroke-width="1.5" fill="none" stroke-linecap="round"/></svg>
      <% :storm -> %>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class={@class} fill="currentColor" aria-hidden="true"><path d="M7 15h9a4 4 0 0 0 0-8 6 6 0 0 0-11.3 1.8A3.5 3.5 0 0 0 7 15Z"/><path d="M11 16l-2 5 5-4-2 5" stroke="currentColor" stroke-width="1.5" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>
      <% :snow -> %>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class={@class} fill="currentColor" aria-hidden="true"><path d="M12 3v18M3 12h18M5 7l14 10M5 17L19 7" stroke="currentColor" stroke-width="1.2" fill="none" stroke-linecap="round"/></svg>
      <% _ -> %>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class={@class} fill="currentColor" aria-hidden="true"><circle cx="12" cy="12" r="6"/></svg>
    <% end %>
    """
  end

  defp coarse(code) when is_integer(code) do
    cond do
      code in [0, 1] -> :clear
      code in [2, 3, 45, 48] -> :cloud
      code in [51, 53, 55, 61, 63, 65, 80, 81, 82] -> :rain
      code in [95, 96, 99] -> :storm
      code in [71, 73, 75] -> :snow
      true -> :cloud
    end
  end
  defp coarse(_), do: :cloud

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
