defmodule UiWeb.HomeLive do
  use UiWeb, :live_view
  require Logger
  alias Core.Brain
  alias Core.Home
  alias Core.Timers

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(Ui.PubSub, "timers")

    {:ok,
     socket
     |> assign(:messages, [
       %{role: :assistant, text: "Hi! I’m your home assistant. Ask me anything."}
     ])
     |> assign(:input, "")}
  end

  @impl true
  def handle_event("send", %{"text" => text}, socket) do
    text = String.trim(to_string(text))
    if text == "" do
      {:noreply, socket}
    else
      msgs = socket.assigns.messages ++ [%{role: :user, text: text}]

      reply =
        case Brain.reply(msgs) do
          {:ok, resp} -> resp
          {:error, :missing_api_key} -> "I can’t reach OpenAI (missing API key)."
          {:error, reason} -> "Sorry, there was an error: #{inspect(reason)}"
        end

      {:noreply, assign(socket, messages: msgs ++ [%{role: :assistant, text: reply}], input: "")}
    end
  end

  def handle_event("quick", %{"action" => "weather"}, socket) do
    send(self(), {:do_brain, "What’s the current weather?"})
    {:noreply, socket}
  end

  def handle_event("quick", %{"action" => "timer"}, socket) do
    case Timers.create_timer(300) do
      {:ok, _id} ->
        {:noreply, append_assistant(socket, "Timer set for 5 minutes.")}
      {:error, reason} ->
        {:noreply, append_assistant(socket, "Could not set timer: #{inspect(reason)}")}
    end
  end

  def handle_event("quick", %{"action" => "toggle_light"}, socket) do
    case Home.toggle("light.kitchen") do
      {:ok, _} -> {:noreply, append_assistant(socket, "Toggled the kitchen light.")}
      {:error, :not_configured} -> {:noreply, append_assistant(socket, "Home Assistant token/base URL not configured.")}
      {:error, reason} -> {:noreply, append_assistant(socket, "Failed to toggle light: #{inspect(reason)}")}
    end
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

      <div class="px-4 pb-2 bg-white/70">
        <div class="grid grid-cols-3 gap-2 pb-3">
          <button phx-click="quick" phx-value-action="weather" class="py-3 px-3 rounded-xl bg-indigo-600 text-white text-base">Weather</button>
          <button phx-click="quick" phx-value-action="timer" class="py-3 px-3 rounded-xl bg-indigo-600 text-white text-base">Set 5m Timer</button>
          <button phx-click="quick" phx-value-action="toggle_light" class="py-3 px-3 rounded-xl bg-indigo-600 text-white text-base">Toggle kitchen light</button>
        </div>
      </div>

      <.simple_form />
    </div>
    """
  end

  defp simple_form(assigns) do
    assigns = Map.put_new(assigns, :input, "")
    ~H"""
    <div class="p-4 bg-white shadow-md">
      <form phx-submit="send" class="flex items-center gap-2">
        <input name="text" value={@input} placeholder="Type a message"
               class="flex-1 px-4 py-4 rounded-2xl border border-gray-300 text-base"
               autocomplete="off" />
        <button type="submit" class="px-6 py-4 rounded-2xl bg-indigo-600 text-white text-base font-semibold">Send</button>
      </form>
    </div>
    """
  end

  @impl true
  def handle_info({:do_brain, text}, socket) do
    msgs = socket.assigns.messages ++ [%{role: :user, text: text}]
    reply =
      case Brain.reply(msgs) do
        {:ok, resp} -> resp
        {:error, :missing_api_key} -> "I can’t reach OpenAI (missing API key)."
        {:error, reason} -> "Sorry, there was an error: #{inspect(reason)}"
      end

    {:noreply, assign(socket, messages: msgs ++ [%{role: :assistant, text: reply}], input: "")}
  end

  def handle_info({:timer_done, id}, socket) do
    {:noreply, append_assistant(socket, "Timer done (##{id}).")}
  end

  defp append_assistant(socket, text) do
    assign(socket, :messages, socket.assigns.messages ++ [%{role: :assistant, text: text}])
  end
end
