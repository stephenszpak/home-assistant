defmodule UiWeb.AnswerCard do
  use Phoenix.Component
  import UiWeb.WeatherComponents

  attr :content, :map, default: nil

  def answer_card(assigns) do
    ~H"""
    <div class="w-full h-full p-[5px]">
      <div class="w-full h-full rounded-2xl bg-white shadow-lg border border-gray-200 overflow-hidden flex relative">
        <button type="button" phx-click="close_answer"
                class="absolute top-3 right-3 z-10 inline-flex items-center justify-center"
                aria-label="Close">
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor"
               class="h-8 w-8 text-gray-500 hover:text-gray-700 transition-colors">
            <path d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20Zm-2.828 6.343 2.828 2.828 2.828-2.828 1.414 1.414L13.414 12l2.828 2.828-1.414 1.414L12 13.414l-2.828 2.828-1.414-1.414L10.586 12 7.758 9.172l1.414-1.414Z"/>
          </svg>
        </button>
        <div class="w-full h-full p-4 overflow-y-auto">
          <%= if is_nil(@content) do %>
            <div class="h-full flex items-center justify-center text-gray-500 text-lg">Ready</div>
          <% else %>
            <%= case @content[:type] do %>
              <% :weather -> %>
                <.weather_panel content={@content} />
              <% :images -> %>
                <.images_grid urls={@content[:urls] || []} caption={@content[:caption]} />
              <% _ -> %>
                <.text_block text={@content[:text]} />
            <% end %>

            <.followups content={@content} />
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Render helpers -----------------------------------------------------------
  attr :content, :map, required: true
  defp weather_panel(assigns) do
    w = assigns.content.weather
    assigns = Map.put(assigns, :w, w)
    ~H"""
    <div>
      <.panel place={@w.place} current={@w.current} daily={@w.daily} />
      <%= if @content[:summary] do %>
        <div class="mt-3 text-gray-600 text-sm"><%= @content[:summary] %></div>
      <% end %>
    </div>
    """
  end

  attr :urls, :list, default: []
  attr :caption, :string, default: nil
  defp images_grid(assigns) do
    ~H"""
    <div class="space-y-3">
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <%= for url <- @urls do %>
          <div class="w-full aspect-video bg-gray-100 rounded-xl overflow-hidden">
            <img src={url} class="w-full h-full object-cover" alt="Generated image" />
          </div>
        <% end %>
      </div>
      <%= if @caption do %>
        <div class="text-gray-700 text-base"><%= @caption %></div>
      <% end %>
    </div>
    """
  end

  attr :text, :string, default: ""
  defp text_block(assigns) do
    ~H"""
    <div class="text-gray-900 text-xl md:text-2xl leading-relaxed whitespace-pre-wrap break-words">
      <%= @text %>
    </div>
    """
  end

  # Follow-up prompt buttons -------------------------------------------------
  attr :content, :map, required: true
  defp followups(assigns) do
    content = assigns.content || %{}
    type = content[:type]
    assigns = Map.put(assigns, :suggestions, suggestions_for(content, type))
    ~H"""
    <%= if length(@suggestions) > 0 do %>
      <div class="mt-6 pt-3 border-t border-gray-200">
        <div class="flex flex-wrap gap-2">
          <%= for s <- @suggestions do %>
            <button type="button" phx-click="send" phx-value-text={s[:text]}
                    class="px-3 h-9 rounded-full text-sm font-medium bg-gray-100 hover:bg-gray-200 text-gray-800 transition-colors">
              <%= s[:label] %>
            </button>
          <% end %>
        </div>
      </div>
    <% end %>
    """
  end

  defp suggestions_for(%{type: :weather} = content, :weather) do
    place = get_in(content, [:weather, :place, :name]) || "your area"
    [
      %{label: "Hourly", text: "Hourly forecast for #{place}"},
      %{label: "Tomorrow", text: "Tomorrow's weather in #{place}"},
      %{label: "5‑day", text: "5-day outlook for #{place}"},
      %{label: "Rain?", text: "Will it rain today in #{place}?"}
    ]
  end
  defp suggestions_for(%{type: :text}, :text) do
    [
      %{label: "More detail", text: "Explain more about that."},
      %{label: "Summarize", text: "Summarize the answer briefly."},
      %{label: "Examples", text: "Give a few concrete examples."},
      %{label: "Next steps", text: "List practical next steps."}
    ]
  end
  defp suggestions_for(_, _), do: []
end
