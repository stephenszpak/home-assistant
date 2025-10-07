defmodule Ui.STT.Streamer do
  @moduledoc """
  OpenAI Realtime streaming client. Accepts audio chunks (base64), sends to
  OpenAI via WebSocket, and forwards partial/final text back to the channel pid.
  """

  use WebSockex
  require Logger

  def start_link(opts) do
    channel = Keyword.fetch!(opts, :channel)
    model = Keyword.get(opts, :model, System.get_env("OPENAI_REALTIME_MODEL", "gpt-4o-realtime-preview"))
    key = Keyword.get(opts, :api_key, System.get_env("OPENAI_API_KEY"))

    if key in [nil, ""] do
      {:error, :missing_api_key}
    else
      url = "wss://api.openai.com/v1/realtime?model=" <> model
      headers = [
        {"authorization", "Bearer " <> key},
        {"openai-beta", "realtime=v1"}
      ]
      state = %{channel: channel, model: model, key: key, buffer: :ok}
      WebSockex.start_link(url, __MODULE__, state, extra_headers: headers)
    end
  end

  # API (cast-style) ---------------------------------------------------------

  def append(pid, b64) when is_binary(b64), do: WebSockex.cast(pid, {:append, b64})
  def commit(pid), do: WebSockex.cast(pid, :commit)
  def create(pid), do: WebSockex.cast(pid, :create)
  def stop(pid), do: WebSockex.cast(pid, :stop)

  # WebSockex callbacks ------------------------------------------------------

  @impl true
  def handle_cast({:append, b64}, state) do
    msg = Jason.encode!(%{type: "input_audio_buffer.append", audio: b64})
    {:reply, {:text, msg}, state}
  end

  def handle_cast(:commit, state) do
    {:reply, {:text, Jason.encode!(%{type: "input_audio_buffer.commit"})}, state}
  end

  def handle_cast(:create, state) do
    # Ask for a text response from the incoming audio
    body = %{type: "response.create", response: %{modalities: ["text"], instructions: "Transcribe the incoming audio."}}
    {:reply, {:text, Jason.encode!(body)}, state}
  end

  def handle_cast(:stop, state) do
    {:close, state}
  end

  @impl true
  def handle_frame({:text, json}, state) do
    case Jason.decode(json) do
      {:ok, %{"type" => "response.delta", "delta" => %{"content" => content}}} ->
        text = extract_text(content)
        if text != "" do
          send(state.channel, {:stt_partial, text})
        end
        {:ok, state}

      {:ok, %{"type" => "response.completed", "response" => %{"output_text" => text}}} ->
        send(state.channel, {:stt_final, to_string(text || "")})
        {:ok, state}

      {:ok, %{"type" => "error", "error" => err}} ->
        Logger.warning("OpenAI realtime error: #{inspect(err)}")
        {:ok, state}

      _ ->
        {:ok, state}
    end
  end

  def handle_frame(_other, state), do: {:ok, state}

  @impl true
  def handle_disconnect(conn_status_map, state) do
    Logger.debug("Realtime disconnected: #{inspect(conn_status_map)}")
    {:ok, state}
  end

  defp extract_text(list) when is_list(list) do
    list
    |> Enum.flat_map(fn
      %{"type" => "input_text", "text" => t} -> [t]
      %{"type" => "output_text", "text" => t} -> [t]
      _ -> []
    end)
    |> Enum.join()
  end
  defp extract_text(_), do: ""
end

