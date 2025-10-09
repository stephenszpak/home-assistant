defmodule UiWeb.HomeLive do
  use UiWeb, :live_view
  require Logger
  alias Core.Brain
  alias Core.Weather

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(Ui.PubSub, "timers")

    {:ok,
     socket
     |> assign(:mic_listening, false)
     |> assign(:speaking, false)
     |> assign(:tts_enabled, true)
     |> assign(:tts_volume, 1.0)
     |> assign(:voice_state, :idle)
     |> assign(:banner_state, :idle)
     |> assign(:banner_text, "")
     |> assign(:banner_mode, :overlay)
     |> assign(:banner_font, "md")
     |> assign(:banner_fading, false)
     |> assign(:auto_hide_ms, 1300)
     |> assign(:banner_hide_ref, nil)
     |> assign(:answer, nil)
     |> assign(:last_utterance, nil)}
  end

  @impl true
  def handle_event("send", %{"text" => text}, socket) do
    text = String.trim(to_string(text))
    if text == "" do
      {:noreply, socket}
    else
      case parse_weather_intent(text) do
        {:weather, place} ->
          case Weather.fetch(place) do
            {:ok, w} ->
              {hi, lo} =
                case Enum.at(w.daily, 0) do
                  %{max_c: maxc, min_c: minc} when is_number(maxc) and is_number(minc) -> {round(maxc), round(minc)}
                  _ -> {nil, nil}
                end
              temp = if is_number(w.current.temperature_c), do: "#{round(w.current.temperature_c)}°C", else: "—"
              city = Map.get(w.place, :name) || ""
              hi_lo = if hi && lo, do: " High #{hi}°/Low #{lo}°.", else: ""
              summary = "Currently #{temp} in #{city}." <> hi_lo
              socket = if socket.assigns[:tts_enabled], do: Phoenix.LiveView.push_event(socket, "tts", %{text: summary, volume: socket.assigns.tts_volume}), else: socket
              ans = %{type: :weather, weather: w, summary: summary}
              ref = Process.send_after(self(), :banner_hide, socket.assigns.auto_hide_ms)
              {:noreply, assign(socket, answer: ans, banner_fading: true, banner_hide_ref: ref)}
            {:error, _} -> {:noreply, assign(socket, answer: %{type: :text, text: "Sorry, I couldn't find weather for #{place}."})}
          end
        :none ->
          case Brain.reply(text) do
            {:ok, resp} ->
              tts_text = first_line(to_string(resp))
              socket = if socket.assigns[:tts_enabled] and tts_text != "", do: Phoenix.LiveView.push_event(socket, "tts", %{text: tts_text, volume: socket.assigns.tts_volume}), else: socket
              ref = Process.send_after(self(), :banner_hide, socket.assigns.auto_hide_ms)
              {:noreply, assign(socket, answer: %{type: :text, text: to_string(resp)}, banner_fading: true, banner_hide_ref: ref)}
            {:error, reason} ->
              {:noreply, assign(socket, answer: %{type: :text, text: "Error: #{inspect(reason)}"})}
          end
      end
    end
  end

  

  

  

  # render and form moved after event handlers to keep all clauses grouped

  

  @impl true
  def handle_event("mic_state", %{"listening" => listening}, socket) do
    {:noreply, assign(socket, :mic_listening, !!listening)}
  end

  @impl true
  def handle_event("mic_live_text", _params, socket) do
    # No-op: banner uses voice:* events; tolerate stray events safely
    {:noreply, socket}
  end

  @impl true
  # removed audio path switch; Ask and Active Chat have dedicated buttons

  @impl true
  def handle_event("mic_button", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("voice_state", %{"state" => state}, socket) do
    atom =
      case state do
        "connecting" -> :connecting
        "listening" -> :listening
        "speaking" -> :speaking
        _ -> :idle
      end
    {:noreply, assign(socket, :voice_state, atom)}
  end

  @impl true
  def handle_event("chat_toggle", _params, socket) do
    case socket.assigns.voice_state do
      :idle -> {:noreply, push_event(socket, "voice:start", %{}) |> assign(:voice_state, :connecting)}
      _ -> {:noreply, push_event(socket, "voice:stop", %{}) |> assign(:voice_state, :idle)}
    end
  end

  @impl true
  def handle_event("voice_session_error", %{"message" => msg}, socket) do
    {:noreply, assign(socket, :voice_state, :idle) |> assign(:answer, %{type: :text, text: "Voice error: #{msg}"})}
  end

  @impl true
  def handle_event("voice_session_stopped", _params, socket) do
    {:noreply, assign(socket, :voice_state, :idle)}
  end

  # Banner controls and events
  @impl true
  def handle_event("voice:start", _params, socket) do
    {:noreply, assign(socket, banner_state: :listening, banner_text: "", banner_fading: false)}
  end

  @impl true
  def handle_event("voice:partial", %{"text" => t}, socket) do
    {:noreply, assign(socket, banner_state: :captioning, banner_text: to_string(t), banner_fading: false)}
  end

  @impl true
  def handle_event("voice:final", %{"text" => t}, socket) do
    {:noreply, assign(socket, banner_state: :finalizing, banner_text: to_string(t), last_utterance: to_string(t), banner_fading: false)}
  end

  @impl true
  def handle_event("voice:cancel", _params, socket) do
    ref = Process.send_after(self(), :banner_hide, 600)
    {:noreply, assign(socket, banner_state: :canceled, banner_hide_ref: ref, banner_fading: true)}
  end

  @impl true
  def handle_event("set_banner_mode", %{"mode" => mode}, socket) do
    m = if mode == "pushdown", do: :pushdown, else: :overlay
    Phoenix.LiveView.push_event(socket, "banner:save", %{mode: mode})
    {:noreply, assign(socket, :banner_mode, m)}
  end

  @impl true
  def handle_event("set_banner_font", %{"font" => font}, socket) do
    Phoenix.LiveView.push_event(socket, "banner:save", %{font: font})
    {:noreply, assign(socket, :banner_font, font)}
  end

  @impl true
  def handle_event("set_hide", %{"ms" => ms}, socket) do
    {int, _} = Integer.parse(ms)
    Phoenix.LiveView.push_event(socket, "banner:save", %{hide: ms})
    {:noreply, assign(socket, :auto_hide_ms, int)}
  end

  @impl true
  def handle_event("banner_settings", %{"mode" => mode, "font" => font, "hide" => hide}, socket) do
    m = case mode do "pushdown" -> :pushdown; "overlay" -> :overlay; _ -> socket.assigns.banner_mode end
    ms = case Integer.parse(to_string(hide || "")) do {v,_}->v; _-> socket.assigns.auto_hide_ms end
    {:noreply, assign(socket, banner_mode: m, banner_font: font || socket.assigns.banner_font, auto_hide_ms: ms)}
  end

  @impl true
  # removed mute/volume controls; TTS remains enabled with default volume

  @impl true
  def handle_event("speaking", %{"state" => state}, socket) do
    {:noreply, assign(socket, :speaking, !!state)}
  end

  @impl true
  def handle_info({:brain_reply, {:ok, resp}}, socket) do
    text = to_string(resp)
    case maybe_weather_fallback(socket, text) do
      {:weather, socket2, w, summary} ->
        {:noreply,
         assign(socket2,
           answer: %{type: :weather, weather: w, summary: summary},
           thinking: false,
           thinking_task: nil,
           banner_state: :idle,
           banner_text: ""
         )}

      :none ->
        socket =
          if socket.assigns[:tts_enabled] do
            tts_text = first_line(text)
            if tts_text != "" do
              Phoenix.LiveView.push_event(socket, "tts", %{text: tts_text, volume: socket.assigns.tts_volume})
            else
              socket
            end
          else
            socket
          end
        {:noreply,
         assign(socket,
           answer: %{type: :text, text: text},
           thinking: false,
           thinking_task: nil,
           banner_state: :idle,
           banner_text: ""
         )}
    end
  end

  def handle_info({:brain_reply, {:error, :missing_api_key}}, socket) do
    {:noreply, assign(socket, answer: %{type: :text, text: "I can’t reach OpenAI (missing API key)."})}
  end

  def handle_info({:brain_reply, {:error, reason}}, socket) do
    {:noreply, assign(socket, answer: %{type: :text, text: "Sorry, there was an error: #{inspect(reason)}"})}
  end

  @impl true
  def handle_info(:reply_started, socket) do
    {:noreply, assign(socket, banner_state: :responding)}
  end

  @impl true
  def handle_info(:reply_finished, socket) do
    ref = Process.send_after(self(), :banner_hide, socket.assigns.auto_hide_ms)
    {:noreply, assign(socket, banner_hide_ref: ref, banner_fading: true)}
  end

  @impl true
  def handle_info(:banner_hide, socket) do
    {:noreply, assign(socket, banner_state: :idle, banner_text: "", banner_hide_ref: nil, banner_fading: false)}
  end


  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-screen bg-gray-100 flex flex-col">
      <div id="live-root" phx-hook="App" class="flex-1 h-full overflow-hidden">
        <.answer_card content={@answer} />
        <%= if @speaking do %>
          <div class="mt-3 text-sm text-gray-600">🔊 speaking...</div>
        <% end %>
      </div>

      <div class="w-full p-[5px]">
        <div id="voice-mode" class="rounded-2xl bg-white shadow-lg border border-gray-200 overflow-hidden p-3 md:p-4 flex items-center gap-3" phx-hook="VoiceMode">
        <!-- Ask (single question, local pipeline) -->
        <button id="ask-btn" type="button" phx-hook="Mic"
                class={[
                  "px-5 h-14 rounded-full text-white text-base font-semibold flex items-center justify-center select-none",
                  if(@mic_listening, do: "bg-red-600 animate-pulse", else: "bg-indigo-600")
                ]}>
          <%= if @mic_listening, do: "Asking…", else: "Ask" %>
        </button>

        <!-- Active Chat (Realtime) -->
        <button id="chat-btn" type="button" phx-click="chat_toggle"
                class={[
                  "px-5 h-14 rounded-full text-white text-base font-semibold flex items-center justify-center select-none",
                  case @voice_state do
                    :connecting -> "bg-amber-500 animate-pulse"
                    :listening -> "bg-red-600 animate-pulse"
                    :speaking -> "bg-red-700 animate-pulse"
                    _ -> "bg-slate-700"
                  end
                ]}>
          <%= case @voice_state do
               :idle -> "Active Chat"
               :connecting -> "Connecting…"
               :listening -> "Listening…"
               :speaking -> "Speaking…"
               _ -> "Active Chat"
             end %>
        </button>

        <!-- Live prompt text moved into bottom bar -->
        <div class="flex-1 min-w-0">
          <div class={[
                 "ml-2 mr-1 flex items-center gap-2 text-gray-900 text-lg md:text-xl leading-snug",
                 "transition-opacity duration-500 ease-linear",
                 if(@banner_state == :idle and @banner_text == "", do: "opacity-0", else: (if @banner_fading, do: "opacity-0", else: "opacity-100"))
               ]}
               aria-live="polite">
            <%= if @banner_state in [:listening, :captioning] do %>
              <span class="inline-flex h-2.5 w-2.5 rounded-full bg-blue-500 animate-pulse"></span>
            <% else %>
              <span class="inline-block w-2.5"></span>
            <% end %>
            <span class="truncate"><%= @banner_text %></span>
          </div>
        </div>
        <!-- Controls removed: mute, volume, and audio path toggles -->
        </div>
      </div>
    </div>
    """
  end

  # no form; inputless kiosk

  # no chat bubbles; answers are rendered via Answer Card

  defp first_line(text) when is_binary(text) do
    text
    |> String.split(["\r\n", "\n"], trim: false)
    |> Enum.find(fn line -> String.trim(line) != "" end)
    |> case do
      nil -> ""
      line -> String.trim(line)
    end
  end
  defp first_line(other), do: other |> to_string() |> first_line()

  defp parse_weather_intent(text) do
    t = text |> to_string() |> String.trim()
    # Strip trailing punctuation
    t = String.replace(t, ~r/[\.\?!]+\s*$/u, "")
    # Match variations
    with [_, place] <- Regex.run(~r/^(?:what'?s|what is)\s+the\s+weather(?:\s+like)?\s+in\s+(.+)$/i, t) do
      {:weather, String.trim(place)}
    else
      _ ->
        case Regex.run(~r/^weather\s+in\s+(.+)$/i, t) do
          [_, place] -> {:weather, String.trim(place)}
          _ ->
            lc = String.downcase(t)
            if lc in ["weather", "what's the weather", "whats the weather"] do
              {:weather, System.get_env("WEATHER_DEFAULT_CITY", "New York")}
            else
              :none
            end
        end
    end
  end

  defp maybe_weather_fallback(socket, llm_text) do
    # If the model claims it can't provide real-time weather, attempt a real fetch
    lt = String.downcase(llm_text || "")
    if String.contains?(lt, "real-time") and String.contains?(lt, "weather") do
      case List.last(socket.assigns.messages) do
        %{role: :user, text: user_text} ->
          case parse_weather_intent(user_text) do
            {:weather, place} ->
              case Weather.fetch(place) do
                {:ok, w} ->
                  {hi, lo} =
                    case Enum.at(w.daily, 0) do
                      %{max_c: maxc, min_c: minc} when is_number(maxc) and is_number(minc) -> {round(maxc), round(minc)}
                      _ -> {nil, nil}
                    end
                  temp = if is_number(w.current.temperature_c), do: "#{round(w.current.temperature_c)}°C", else: "—"
                  city = Map.get(w.place, :name) || place
                  hi_lo = if hi && lo, do: " High #{hi}°/Low #{lo}°.", else: ""
                  summary = "Currently #{temp} in #{city}." <> hi_lo
                  socket2 = if socket.assigns[:tts_enabled], do: Phoenix.LiveView.push_event(socket, "tts", %{text: summary, volume: socket.assigns.tts_volume}), else: socket
                  {:weather, socket2, w, summary}
                _ -> :none
              end
            _ -> :none
          end
        _ -> :none
      end
    else
      :none
    end
  end
end
