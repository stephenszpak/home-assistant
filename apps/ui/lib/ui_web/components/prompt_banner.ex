defmodule UiWeb.PromptBanner do
  use Phoenix.Component

  attr :state, :atom, default: :idle
  attr :text, :string, default: ""
  attr :mode, :atom, default: :overlay
  attr :font, :string, default: "md" # "sm" | "md" | "lg"
  attr :on_cancel, :any, default: nil

  def banner(assigns) do
    ~H"""
    <%= if @state != :idle do %>
      <div role="status" aria-live="polite"
           class={["prompt-banner fixed inset-x-0 top-0 z-40",
                   if(@mode == :overlay, do: "shadow-lg", else: "")]}>
        <div class={["mx-auto w-full max-w-screen-xl flex items-center gap-3 px-4",
                     "h-16 md:h-18",
                     font_class(@font)]}>
          <div class="flex items-center gap-2">
            <div class={state_chip_class(@state)}><%= state_label(@state) %></div>
            <div class="h-2 w-2 rounded-full bg-blue-300 animate-pulse"></div>
          </div>
          <div class="flex-1 text-[18px] md:text-[20px] leading-snug line-clamp-2 text-[#e6eefc]">
            <%= @text %>
          </div>
          <button type="button" phx-click={@on_cancel || "voice:cancel"}
                  class="ml-3 text-[#e6eefc]/70 hover:text-white text-xl px-2"
                  aria-label="Cancel">
            ×
          </button>
        </div>
      </div>
    <% end %>
    """
  end

  defp state_label(:listening), do: "Listening…"
  defp state_label(:captioning), do: "Speaking…"
  defp state_label(:finalizing), do: "Finalizing…"
  defp state_label(:responding), do: "Responding…"
  defp state_label(:canceled), do: "Canceled"
  defp state_label(_), do: ""

  defp state_chip_class(state) do
    base = "px-2 py-1 rounded-md text-xs font-semibold"
    case state do
      :listening -> base <> " bg-blue-500/70 text-white"
      :captioning -> base <> " bg-indigo-500/70 text-white"
      :finalizing -> base <> " bg-amber-500/70 text-white"
      :responding -> base <> " bg-green-600/70 text-white"
      :canceled -> base <> " bg-gray-500/70 text-white"
      _ -> base <> " bg-slate-600/70 text-white"
    end
  end

  defp font_class("sm"), do: "text-[16px]"
  defp font_class("lg"), do: "text-[20px]"
  defp font_class(_), do: "text-[18px]"
end

