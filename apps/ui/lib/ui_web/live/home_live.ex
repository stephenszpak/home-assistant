defmodule UiWeb.HomeLive do
  use UiWeb, :live_view
  require Logger
  alias Core.Brain
  alias Core.Weather

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(Ui.PubSub, "timers")

    socket =
      socket
      |> assign(:mode, :clock)
      |> assign(:closing, false)
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
      |> assign(:last_utterance, nil)
      |> assign(:clock_use_24h, false)
      |> assign(:clock_show_seconds, false)
      |> assign(:clock_tz, nil)
      |> assign(:sleep_timeout_ms, sleep_timeout_ms_from_env())
      |> assign(:clock_weather, nil)
      |> assign(:ha_connected?, !!Application.get_env(:core, :ha_token))
      |> assign(:dimming, false)
      # Calendar UI removed
      |> assign(:clock_weather_place, weather_place_from_env())

    socket =
      if connected?(socket) do
        send(self(), :load_weather)
        socket
      else
        socket
      end

    {:ok, socket}
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
              socket = assign(socket, answer: ans, banner_fading: true, banner_hide_ref: ref, mode: :answer)
              {:noreply, Phoenix.LiveView.push_event(socket, "answer:updated", %{})}
            {:error, _} -> {:noreply, assign(socket, answer: %{type: :text, text: "Sorry, I couldn't find weather for #{place}."})}
          end
        :none ->
          case Brain.reply(text) do
            {:ok, resp} ->
              tts_text = first_line(to_string(resp))
              socket = if socket.assigns[:tts_enabled] and tts_text != "", do: Phoenix.LiveView.push_event(socket, "tts", %{text: tts_text, volume: socket.assigns.tts_volume}), else: socket
              ref = Process.send_after(self(), :banner_hide, socket.assigns.auto_hide_ms)
              socket = assign(socket, answer: %{type: :text, text: to_string(resp)}, banner_fading: true, banner_hide_ref: ref, mode: :answer)
              {:noreply, Phoenix.LiveView.push_event(socket, "answer:updated", %{})}
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
    socket = assign(socket, :voice_state, atom)
    socket = if atom == :connecting, do: assign(socket, :mode, :voice), else: socket
    {:noreply, Phoenix.LiveView.push_event(socket, "voice:state", %{state: to_string(state)})}
  end

  @impl true
  def handle_event("chat_toggle", _params, socket) do
    case socket.assigns.voice_state do
      :idle -> {:noreply, push_event(socket, "voice:start", %{}) |> assign(:voice_state, :connecting) |> assign(:mode, :voice)}
      _ -> {:noreply, push_event(socket, "voice:stop", %{}) |> assign(:voice_state, :idle)}
    end
  end

  @impl true
  def handle_event("voice_session_error", %{"message" => msg}, socket) do
    {:noreply, assign(socket, :voice_state, :idle) |> assign(:answer, %{type: :text, text: "Voice error: #{msg}"}) |> assign(:mode, :answer)}
  end

  @impl true
  def handle_event("voice_session_stopped", _params, socket) do
    mode = if socket.assigns[:answer], do: :answer, else: :clock
    {:noreply, assign(socket, :voice_state, :idle) |> assign(:mode, mode)}
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
  def handle_event("speaking", %{"state" => state}, socket) do
    {:noreply, assign(socket, :speaking, !!state)}
  end

  # Grouped UI and clock events
  @impl true
  def handle_event("ui:sleep", _params, socket) do
    Process.send_after(self(), :sleep_now, 1200)
    {:noreply, assign(socket, :dimming, true)}
  end

  @impl true
  def handle_event("close_answer", _params, socket) do
    Process.send_after(self(), :do_close, 250)
    {:noreply, assign(socket, :closing, true)}
  end

  @impl true
  def handle_event("clock:prefs", %{"clock_use_24h" => u24, "clock_show_seconds" => show, "clock_tz" => tz}, socket) do
    u24b = if is_boolean(u24), do: u24, else: false
    showb = if is_boolean(show), do: show, else: false
    {:noreply, assign(socket, clock_use_24h: u24b, clock_show_seconds: showb, clock_tz: tz)}
  end

  @impl true
  def handle_event("ask:started", _params, socket) do
    {:noreply, Phoenix.LiveView.push_event(socket, "ask:started", %{})}
  end

  @impl true
  def handle_event("ask:ended", _params, socket) do
    {:noreply, Phoenix.LiveView.push_event(socket, "ask:ended", %{})}
  end

  # Calendar test removed

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
           banner_text: "",
           mode: :answer
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
        socket = assign(socket,
           answer: %{type: :text, text: text},
           thinking: false,
           thinking_task: nil,
           banner_state: :idle,
           banner_text: "",
           mode: :answer
         )
        {:noreply, Phoenix.LiveView.push_event(socket, "answer:updated", %{})}
    end
  end

  # local TTS summary dispatch
  @impl true
  def handle_info({:tts, text}, socket) do
    t = to_string(text || "")
    if socket.assigns[:tts_enabled] and t != "" do
      {:noreply, Phoenix.LiveView.push_event(socket, "tts", %{text: t, volume: socket.assigns.tts_volume})}
    else
      {:noreply, socket}
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
  def handle_info(:load_weather, socket) do
    place = socket.assigns.clock_weather_place
    {lat, lon} =
      case {System.get_env("CLOCK_WEATHER_LAT"), System.get_env("CLOCK_WEATHER_LON")} do
        {lat_s, lon_s} when is_binary(lat_s) and is_binary(lon_s) ->
          with {lat, _} <- Float.parse(lat_s), {lon, _} <- Float.parse(lon_s) do
            {lat, lon}
          else
            _ -> {nil, nil}
          end
        _ -> {nil, nil}
      end

    result =
      case {lat, lon} do
        {l1, l2} when is_number(l1) and is_number(l2) -> Core.Weather.fetch(l1, l2)
        _ -> Core.Weather.fetch(place)
      end

    case result do
      {:ok, w} ->
        # schedule periodic refresh (30 minutes)
        Process.send_after(self(), :refresh_weather, 30 * 60 * 1000)
        {:noreply, assign(socket, :clock_weather, w)}
      {:error, reason} ->
        require Logger
        Logger.warning("clock weather fetch failed: #{inspect(reason)} for #{place}")
        # retry after 2 minutes on failure
        Process.send_after(self(), :load_weather, 2 * 60 * 1000)
        {:noreply, socket}
      _ ->
        Process.send_after(self(), :load_weather, 2 * 60 * 1000)
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:refresh_weather, socket) do
    send(self(), :load_weather)
    {:noreply, socket}
  end

  @impl true
  # Calendar loader removed

  @impl true
  def handle_info(:do_close, socket) do
    {:noreply, assign(socket, mode: :clock, answer: nil, closing: false)}
  end

  @impl true
  def handle_info(:sleep_now, socket) do
    {:noreply, assign(socket, mode: :clock, dimming: false)}
  end


  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-screen bg-gray-100 flex flex-col">
      <div id="live-root" phx-hook="App" class="flex-1 h-full overflow-hidden">
        <div id="root" phx-hook="Ambient" class={[
              "relative h-full w-full transition-opacity duration-700",
              if(@dimming, do: "opacity-60", else: "opacity-100")
            ]}>
          <%= if @mode == :clock do %>
            <div id="clock-wrap" class="h-full w-full">
              <div class="w-full h-full px-3 py-3 md:px-4 md:py-4">
                <div class="w-full h-full rounded-3xl bg-white/90 dark:bg-neutral-900/80 elev-2 hairline overflow-hidden">
                  <div class="h-full w-full grid grid-cols-12 gap-2 md:gap-3">
                    <div id="clock-left" class="col-span-12 md:col-span-8 lg:col-span-9 h-full grid place-items-center" phx-hook="ClockTick">
                      <.clock_face align="left" time_zone={@clock_tz} show_seconds?={@clock_show_seconds} use_24h?={@clock_use_24h} />
                    </div>
                    <div id="weather-cycle" class="col-span-12 md:col-span-4 lg:col-span-3 h-full flex flex-col items-end justify-center pr-6 md:pr-10 lg:pr-16 xl:pr-24 overflow-y-auto" phx-hook="WeatherCycle">
                      <%= if @clock_weather do %>
                        <.tile weather={@clock_weather} />
                      <% else %>
                        <div class="text-right text-gray-500">Loading weather…</div>
                      <% end %>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          <% else %>
            <div id="content-wrap" phx-hook="SleepManager" data-sleep-timeout-ms={@sleep_timeout_ms}
                 class={[
                   "relative h-full w-full transition-opacity duration-300",
                   if(@closing, do: "opacity-0 pointer-events-none", else: "opacity-100")
                 ]}>
              <%= if @mode == :voice do %>
                <div class="w-full h-full p-[5px]">
                  <div class="w-full h-full rounded-2xl bg-white dark:bg-neutral-900 shadow-lg border border-gray-200 dark:border-white/10 overflow-hidden flex flex-col">
                    <div class="px-4 py-3 border-b border-gray-200 dark:border-white/10 flex items-center justify-between">
                      <div class="text-base font-semibold">Active Chat</div>
                      <button type="button" phx-click="chat_toggle" class="text-sm px-3 h-8 rounded-full bg-gray-100 dark:bg-neutral-800 hover:bg-gray-200 dark:hover:bg-neutral-700">Stop</button>
                    </div>
                    <div class="flex-1 overflow-y-auto p-4 space-y-3">
                      <%= for m <- @conversation_messages do %>
                        <div class="flex justify-end">
                          <div class="max-w-[80%] rounded-2xl px-3 py-2 bg-indigo-600 text-white text-sm"> <%= m.text %> </div>
                        </div>
                      <% end %>
                    </div>
                  </div>
                </div>
              <% else %>
                <%= if @speaking do %>
                  <div class="absolute inset-x-0 top-0 progress-bar"></div>
                <% end %>
                <.answer_card content={@answer} />
              <% end %>
            </div>
          <% end %>
        </div>
      </div>

      <div class="w-full px-3 pb-3 md:px-4 md:pb-4">
        <div id="voice-mode" phx-hook="VoiceMode"
             class={[
               "fixed inset-x-3 bottom-3 md:inset-x-4 md:bottom-4 z-50 glass hairline elev-1 rounded-3xl p-3 md:p-4 flex items-center gap-3",
               "transition-opacity duration-300 ease-out",
               if(@mode == :clock, do: "opacity-100", else: "opacity-0 pointer-events-none")
             ]}>
        <!-- Ask (single question, local pipeline) -->
        <button id="ask-btn" type="button" phx-hook="Mic"
                class={[
                  "px-5 h-12 md:h-14 rounded-full text-white text-base font-semibold flex items-center justify-center select-none gap-2",
                  if(@mic_listening, do: "bg-red-600 animate-pulse", else: "bg-indigo-600")
                ]} aria-label="Ask (tap to speak)">
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" class="h-5 w-5 fill-current"><path d="M12 15a3 3 0 0 0 3-3V7a3 3 0 0 0-6 0v5a3 3 0 0 0 3 3Zm-7-3a7 7 0 0 0 14 0h-2a5 5 0 0 1-10 0H5Z"/></svg>
          <%= if @mic_listening, do: "Asking…", else: "Ask" %>
        </button>

        <!-- Live prompt text moved into bottom bar -->
        <div class="flex-1 min-w-0">
          <div class={[
                 "ml-2 mr-1 flex items-center gap-2 text-gray-900 text-base md:text-lg leading-snug",
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
        <!-- Hint: Start Active Chat via voice -->
        <div class="hidden sm:flex items-center gap-2 text-xs md:text-sm text-neutral-600 dark:text-neutral-300 ml-2 whitespace-nowrap select-none">
          <span>Tip: say “start active chat”</span>
        </div>
        </div>
      </div>
    </div>
    """
  end

  # Client sleep (moved and grouped above with other handle_event clauses)

  defp sleep_timeout_ms_from_env do
    case Integer.parse(System.get_env("CLOCK_SLEEP_TIMEOUT_MS", "")) do
      {v, _} when v > 0 -> v
      _ -> Application.get_env(:ui, :sleep_timeout_ms, 60_000)
    end
  end

  defp weather_place_from_env do
    System.get_env("CLOCK_WEATHER_PLACE", "Murfreesboro TN")
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

  # Calendar intent and summaries removed

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

  # Helpers for clock weather UI --------------------------------------------
end
