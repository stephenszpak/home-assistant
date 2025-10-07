defmodule UiWeb.HomeLive do
  use UiWeb, :live_view
  require Logger
  alias Core.Brain

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(Ui.PubSub, "timers")

    {:ok,
     socket
     |> assign(:messages, [
        %{role: :assistant, text: "Hi! I’m your home assistant. Ask me anything."}
      ])
     |> assign(:input, "")
     |> assign(:live_text, "")
     |> assign(:thinking, false)
     |> assign(:thinking_task, nil)
     |> assign(:mic_listening, false)
     |> assign(:speaking, false)
     |> assign(:tts_enabled, true)
     |> assign(:tts_volume, 1.0)}
  end

  @impl true
  def handle_event("send", %{"text" => text}, socket) do
    text = String.trim(to_string(text))
    if text == "" do
      {:noreply, socket}
    else
      msgs = case List.last(socket.assigns.messages) do
        %{role: :user, text: ^text} -> socket.assigns.messages
        _ -> socket.assigns.messages ++ [%{role: :user, text: text}]
      end
      parent = self()
      {:ok, pid} = Task.start(fn -> send(parent, {:brain_reply, Brain.reply(msgs)}) end)
      {:noreply, assign(socket, messages: msgs, input: "", thinking: true, thinking_task: pid)}
    end
  end

  

  

  

  # render and form moved after event handlers to keep all clauses grouped

  

  @impl true
  def handle_event("mic_live_text", %{"text" => text}, socket) do
    {:noreply, assign(socket, :live_text, to_string(text))}
  end

  @impl true
  def handle_event("mic_state", %{"listening" => listening}, socket) do
    {:noreply, assign(socket, :mic_listening, !!listening)}
  end

  @impl true
  def handle_event("stop_thinking", _params, socket) do
    case socket.assigns.thinking_task do
      pid when is_pid(pid) -> Process.exit(pid, :kill)
      _ -> :ok
    end
    {:noreply, assign(socket, thinking: false, thinking_task: nil)}
  end

  @impl true
  def handle_event("toggle_tts", _params, socket) do
    {:noreply, assign(socket, :tts_enabled, !socket.assigns.tts_enabled)}
  end

  @impl true
  def handle_event("tts_volume", %{"volume" => vol}, socket) do
    vol = case Float.parse(to_string(vol)) do
      {v, _} when v >= 0.0 and v <= 1.0 -> v
      {v, _} when v < 0.0 -> 0.0
      {v, _} when v > 1.0 -> 1.0
      _ -> socket.assigns.tts_volume
    end
    {:noreply, assign(socket, :tts_volume, vol)}
  end

  @impl true
  def handle_info({:brain_reply, {:ok, resp}}, socket) do
    text = to_string(resp)
    socket =
      if socket.assigns[:tts_enabled] do
        Phoenix.LiveView.push_event(socket, "tts", %{text: text, volume: socket.assigns.tts_volume})
      else
        socket
      end

    {:noreply,
     assign(socket,
       messages: socket.assigns.messages ++ [%{role: :assistant, text: text}],
       thinking: false,
       thinking_task: nil
     )}
  end

  def handle_info({:brain_reply, {:error, :missing_api_key}}, socket) do
    {:noreply,
     socket
     |> assign(:thinking, false)
     |> assign(:thinking_task, nil)
     |> append_assistant("I can’t reach OpenAI (missing API key).")}
  end

  def handle_info({:brain_reply, {:error, reason}}, socket) do
    {:noreply,
     socket
     |> assign(:thinking, false)
     |> assign(:thinking_task, nil)
     |> append_assistant("Sorry, there was an error: #{inspect(reason)}")}
  end

  @impl true
  def handle_event("speaking", %{"state" => state}, socket) do
    {:noreply, assign(socket, :speaking, !!state)}
  end

  @impl true
  def handle_info({:do_brain, text}, socket) do
    msgs = case List.last(socket.assigns.messages) do
      %{role: :user, text: ^text} -> socket.assigns.messages
      _ -> socket.assigns.messages ++ [%{role: :user, text: text}]
    end
    parent = self()
    {:ok, pid} = Task.start(fn -> send(parent, {:brain_reply, Brain.reply(msgs)}) end)
    {:noreply, assign(socket, messages: msgs, thinking: true, thinking_task: pid)}
  end

  def handle_info({:timer_done, id}, socket) do
    {:noreply, append_assistant(socket, "Timer done (##{id}).")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-100 flex flex-col">
      <div id="live-root" phx-hook="App" class="flex-1 p-4 space-y-3 overflow-y-auto">
        <%= for msg <- @messages do %>
          <.chat_bubble role={msg.role} text={msg.text} />
        <% end %>
        <%= if @thinking do %>
          <.chat_bubble role={:assistant} text={"Thinking..."} />
        <% end %>
        <%= if @live_text != "" do %>
          <div class="opacity-70">
            <.chat_bubble role={:user} text={@live_text} />
          </div>
        <% end %>
        <%= if @speaking do %>
          <div class="text-sm text-gray-600">🔊 speaking...</div>
        <% end %>
      </div>

      <div class="p-4 bg-white shadow-md flex items-center gap-2">
        <button id="mic-btn" type="button" phx-hook="Mic"
                class={[
                  "w-14 h-14 rounded-full text-white text-2xl flex items-center justify-center select-none",
                  if(@mic_listening, do: "bg-red-600 animate-pulse", else: "bg-indigo-600")
                ]}>
          <%= if @mic_listening, do: "…", else: "🎤" %>
        </button>
        <.simple_form thinking={@thinking} input={@input} />
        <div class="flex items-center gap-2 ml-2">
          <button type="button" phx-click="toggle_tts" class="px-3 py-2 rounded-xl border text-sm">
            <%= if @tts_enabled, do: "🔈", else: "🔇" %>
          </button>
          <input type="range" min="0" max="1" step="0.1" value={@tts_volume}
                 phx-change="tts_volume" name="volume" class="w-24" />
        </div>
      </div>
    </div>
    """
  end

  defp simple_form(assigns) do
    assigns = assigns |> Map.put_new(:input, "") |> Map.put_new(:thinking, false)
    ~H"""
    <div class="flex-1">
      <form phx-submit="send" class="flex items-center gap-2">
        <input name="text" value={@input} placeholder="Type a message"
               class="flex-1 px-4 py-4 rounded-2xl border border-gray-300 text-base"
               autocomplete="off" />
        <%= if @thinking do %>
          <button type="button" phx-click="stop_thinking" class="px-6 py-4 rounded-2xl bg-red-600 text-white text-base font-semibold">Stop</button>
        <% else %>
          <button type="submit" class="px-6 py-4 rounded-2xl bg-indigo-600 text-white text-base font-semibold">Send</button>
        <% end %>
      </form>
    </div>
    """
  end

  defp append_assistant(socket, text) do
    assign(socket, :messages, socket.assigns.messages ++ [%{role: :assistant, text: text}])
  end
end
