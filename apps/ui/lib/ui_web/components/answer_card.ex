defmodule UiWeb.AnswerCard do
  use Phoenix.Component
  import UiWeb.WeatherComponents

  attr :content, :map, default: nil

  def answer_card(assigns) do
    ~H"""
    <div class="w-full h-full p-[5px]">
      <div class="w-full h-full rounded-2xl bg-white shadow-lg border border-gray-200 overflow-hidden flex">
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
end
