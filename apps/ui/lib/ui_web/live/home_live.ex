defmodule UiWeb.HomeLive do
  use UiWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:listening, false)
     |> assign(:messages, [
       %{role: :assistant, text: "Hi! Tap the mic to talk."}
     ])}
  end

  @impl true
  def handle_event("toggle_mic", _params, socket) do
    listening = !socket.assigns.listening
    {:noreply, assign(socket, :listening, listening)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-100 flex flex-col">
      <div class="flex-1 p-4 space-y-3 overflow-y-auto">
        <%= for msg <- @messages do %>
          <.chat_bubble role={msg.role} text={msg.text} />
        <% end %>
      </div>
      <div class="p-6 bg-white shadow-md">
        <button phx-click="toggle_mic"
                class={[
                  "w-full py-6 rounded-full text-white text-xl font-semibold transition",
                  if(@listening, do: "bg-red-600 animate-pulse", else: "bg-indigo-600 hover:bg-indigo-700")
                ]}>
          <%= if @listening, do: "Listening…", else: "Tap to Speak" %>
        </button>
      </div>
    </div>
    """
  end
end

