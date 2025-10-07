defmodule UiWeb.SttChannel do
  use Phoenix.Channel

  require Logger

  @impl true
  def join("stt:" <> _session, _params, socket) do
    {:ok, assign(socket, path: nil, bytes: 0, mime: nil, filename: nil)}
  end

  @impl true
  def handle_in("start", %{"mime" => mime} = _payload, socket) do
    ext =
      case mime do
        "audio/webm" -> ".webm"
        "audio/ogg" -> ".ogg"
        _ -> ".bin"
      end

    path = Path.join(System.tmp_dir!(), "stt-" <> Base.encode16(:crypto.strong_rand_bytes(8)) <> ext)

    case File.open(path, [:write]) do
      {:ok, io} -> :ok = File.close(io)
      {:error, reason} ->
        Logger.error("STT start failed to create file: #{inspect(reason)}")
        {:reply, {:error, %{error: "init_failed"}}, socket}
    end

    socket = assign(socket, path: path, mime: mime, filename: "audio" <> ext)

    # Try to start realtime streamer (optional)
    streamer =
      case Ui.STT.Streamer.start_link(channel: self()) do
        {:ok, pid} -> pid
        _ -> nil
      end
    {:reply, {:ok, %{ok: true}}, assign(socket, streamer: streamer)}
  end

  def handle_in("chunk", %{"data" => _b64}, %{assigns: %{path: nil}} = socket) do
    {:reply, {:error, %{error: "not_started"}}, socket}
  end

  def handle_in("chunk", %{"data" => b64}, socket) do
    with {:ok, bin} <- Base.decode64(b64),
         :ok <- append(socket.assigns.path, bin) do
      if pid = socket.assigns[:streamer] do
        _ = Ui.STT.Streamer.append(pid, b64)
      end
      bytes = socket.assigns.bytes + byte_size(bin)
      {:reply, {:ok, %{bytes: bytes}}, assign(socket, :bytes, bytes)}
    else
      {:error, reason} -> {:reply, {:error, %{error: inspect(reason)}}, socket}
    end
  end

  def handle_in("stop", _payload, socket) do
    if pid = socket.assigns[:streamer] do
      Ui.STT.Streamer.commit(pid)
      Ui.STT.Streamer.create(pid)
    end

    result = transcribe(socket.assigns)
    _ = cleanup(socket.assigns.path)
    case result do
      {:ok, text} ->
        push(socket, "final", %{text: text})
        {:reply, {:ok, %{text: text}}, assign(socket, path: nil, bytes: 0)}
      {:error, reason} ->
        Logger.warning("STT final failed: #{inspect(reason)}")
        {:reply, {:error, %{error: inspect(reason)}}, assign(socket, path: nil, bytes: 0)}
    end
  end

  defp append(path, bin) do
    File.write(path, bin, [:append])
  end

  defp cleanup(nil), do: :ok
  defp cleanup(path) do
    File.rm(path)
    :ok
  end

  @impl true
  def handle_info({:stt_partial, text}, socket) do
    push(socket, "partial", %{text: to_string(text)})
    {:noreply, socket}
  end

  def handle_info({:stt_final, text}, socket) do
    push(socket, "final", %{text: to_string(text)})
    {:noreply, socket}
  end

  defp transcribe(%{path: nil}), do: {:error, :no_audio}
  defp transcribe(%{path: path, filename: filename, mime: mime}) do
    stt_url = System.get_env("STT_URL")
    cond do
      is_binary(stt_url) and String.downcase(stt_url) == "openai" -> forward_openai(path, filename, mime)
      is_binary(stt_url) and stt_url != "" -> forward_http(stt_url, path, filename, mime)
      true -> {:error, :no_url}
    end
  end

  defp forward_openai(path, filename, mime) do
    api_key = System.get_env("OPENAI_API_KEY")
    if api_key in [nil, ""], do: {:error, :missing_api_key}, else: :ok
    model = System.get_env("OPENAI_STT_MODEL", "gpt-4o-mini-transcribe")
    fields = [{"model", model}]
    {body, content_type} = multipart_body_with_fields(fields, path, filename, mime)
    req = Req.new()
          |> Req.merge(url: "https://api.openai.com/v1/audio/transcriptions",
            headers: [{"content-type", content_type}, {"authorization", "Bearer " <> api_key}],
            retry: :transient, retry_log_level: :warn, receive_timeout: 60_000, connect_options: [timeout: 5_000])
    case Req.post(req, body: body) do
      {:ok, %{status: 200, body: %{"text" => text}}} when is_binary(text) -> {:ok, text}
      {:ok, %{status: s, body: b}} -> {:error, {:http_error, s, b}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp forward_http(url, path, filename, mime) do
    url = normalize_url(url)
    {body, content_type} = multipart_body(path, filename, mime)
    req = Req.new()
          |> Req.merge(url: url, headers: [{"content-type", content_type}], retry: :transient, retry_log_level: :warn, receive_timeout: 60_000, connect_options: [timeout: 5_000])
    case Req.post(req, body: body) do
      {:ok, %{status: 200, body: %{"text" => text}}} when is_binary(text) -> {:ok, text}
      {:ok, %{status: 200, body: body}} when is_binary(body) -> {:ok, body}
      {:ok, %{status: s, body: b}} -> {:error, {:http_error, s, b}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_url(url) do
    uri = URI.parse(url)
    host = if uri.host in ["localhost", "127.0.0.1"], do: "host.docker.internal", else: uri.host
    URI.to_string(%{uri | host: host})
  end

  defp multipart_body(path, filename, content_type) do
    boundary = "---------------------------" <> Base.encode16(:crypto.strong_rand_bytes(16))
    file_bin = File.read!(path)
    preamble = [
      "--", boundary, "\r\n",
      "Content-Disposition: form-data; name=\"file\"; filename=\"", filename, "\"\r\n",
      "Content-Type: ", content_type, "\r\n\r\n"
    ]
    ending = ["\r\n--", boundary, "--\r\n"]
    body = [preamble, file_bin, ending]
    {body, "multipart/form-data; boundary=" <> boundary}
  end

  defp multipart_body_with_fields(fields, path, filename, content_type) do
    boundary = "---------------------------" <> Base.encode16(:crypto.strong_rand_bytes(16))
    parts =
      Enum.flat_map(fields, fn {name, value} ->
        [
          "--", boundary, "\r\n",
          "Content-Disposition: form-data; name=\"", name, "\"\r\n\r\n",
          to_string(value), "\r\n"
        ]
      end)
    file_bin = File.read!(path)
    file_part = [
      "--", boundary, "\r\n",
      "Content-Disposition: form-data; name=\"file\"; filename=\"", filename, "\"\r\n",
      "Content-Type: ", content_type, "\r\n\r\n",
      file_bin, "\r\n"
    ]
    ending = ["--", boundary, "--\r\n"]
    body = [parts, file_part, ending]
    {body, "multipart/form-data; boundary=" <> boundary}
  end
end
