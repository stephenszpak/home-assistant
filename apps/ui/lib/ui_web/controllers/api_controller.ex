defmodule UiWeb.ApiController do
  use Phoenix.Controller, formats: [:json]

  def stt(conn, params) do
    stt_url = System.get_env("STT_URL")

    with {:ok, upload} <- fetch_upload(params),
         {:ok, url} <- ensure_url(stt_url),
         {:ok, result} <- dispatch_stt(url, upload) do
      json(conn, %{text: result})
    else
      {:error, :no_file} -> json(conn |> Plug.Conn.put_status(400), %{error: "missing file"})
      {:error, :no_url} -> json(conn |> Plug.Conn.put_status(500), %{error: "STT_URL not set"})
      {:error, %Req.TransportError{reason: reason}} -> json(conn |> Plug.Conn.put_status(502), %{error: inspect(reason)})
      {:error, reason} -> json(conn |> Plug.Conn.put_status(502), %{error: inspect(reason)})
    end
  end

  def tts(conn, %{"text" => text}) do
    text = String.trim(to_string(text || ""))
    tts_url = System.get_env("TTS_URL")

    with true <- text != "",
         {:ok, url} <- ensure_url(tts_url),
         {:ok, {body, ctype}} <- dispatch_tts(url, text) do
      ctype = normalize_ctype(ctype)
      conn
      |> Plug.Conn.put_resp_header("content-type", ctype)
      |> Plug.Conn.send_resp(200, body)
    else
      false -> json(conn |> Plug.Conn.put_status(400), %{error: "missing text"})
      {:error, :no_url} -> json(conn |> Plug.Conn.put_status(500), %{error: "TTS_URL not set"})
      {:error, %Req.TransportError{reason: reason}} -> json(conn |> Plug.Conn.put_status(502), %{error: inspect(reason)})
      {:error, reason} -> json(conn |> Plug.Conn.put_status(502), %{error: inspect(reason)})
    end
  end

  defp fetch_upload(%{"file" => %Plug.Upload{} = up}), do: {:ok, up}
  defp fetch_upload(%{"file" => list}) when is_list(list) do
    case Enum.find(list, &match?(%Plug.Upload{}, &1)) do
      %Plug.Upload{} = up -> {:ok, up}
      _ -> {:error, :no_file}
    end
  end
  defp fetch_upload(_), do: {:error, :no_file}

  defp ensure_url(nil), do: {:error, :no_url}
  defp ensure_url(url) when is_binary(url) and url != "", do: {:ok, url}
  defp ensure_url(_), do: {:error, :no_url}

  # When running inside Docker on macOS, requests to localhost from the container
  # must target host.docker.internal to reach services running on the host.
  defp normalize_url(url) when is_binary(url) do
    uri = URI.parse(url)
    host = uri.host
    host = if host in ["localhost", "127.0.0.1"], do: "host.docker.internal", else: host
    uri = %{uri | host: host}
    URI.to_string(uri)
  end

  defp dispatch_stt(url, %Plug.Upload{} = upload) do
    url_down = String.downcase(url)
    cond do
      url_down in ["openai", "openai://", "openai:transcribe"] -> forward_openai(upload)
      true -> forward_stt(normalize_url(url), upload)
    end
  end

  defp forward_openai(%Plug.Upload{path: path, filename: filename, content_type: ct}) do
    api_key = System.get_env("OPENAI_API_KEY")
    if is_nil(api_key) or api_key == "" do
      {:error, :missing_api_key}
    else
      model = System.get_env("OPENAI_STT_MODEL", "gpt-4o-mini-transcribe")

      fields = [{"model", model}]
      {body, content_type} = multipart_body_with_fields(fields, path, filename || "audio.webm", ct || "application/octet-stream")

      req =
        Req.new()
        |> Req.merge(
          url: "https://api.openai.com/v1/audio/transcriptions",
          headers: [{"content-type", content_type}, {"authorization", "Bearer " <> api_key}],
          retry: :transient,
          retry_log_level: :warn,
          receive_timeout: 60_000,
          connect_options: [timeout: 5_000]
        )

      case Req.post(req, body: body) do
        {:ok, %{status: 200, body: %{"text" => text}}} when is_binary(text) -> {:ok, text}
        {:ok, %{status: s, body: b}} -> {:error, {:http_error, s, b}}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp forward_stt(url, %Plug.Upload{path: path, filename: filename, content_type: ct}) do
    {body, content_type} = multipart_body(path, filename || "audio.webm", ct || "application/octet-stream")

    req =
      Req.new()
      |> Req.merge(
        url: url,
        headers: [{"content-type", content_type}],
        retry: :transient,
        retry_log_level: :warn,
        receive_timeout: 60_000,
        connect_options: [timeout: 5_000]
      )

    case Req.post(req, body: body) do
      {:ok, %{status: 200, body: %{"text" => text}}} when is_binary(text) -> {:ok, text}
      {:ok, %{status: 200, body: body}} when is_binary(body) -> {:ok, body}
      {:ok, %{status: s, body: b}} -> {:error, {:http_error, s, b}}
      {:error, reason} -> {:error, reason}
    end
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

  defp dispatch_tts(url, text) when is_binary(url) do
    url_down = String.downcase(url)
    cond do
      url_down in ["openai", "openai://", "openai:tts"] -> forward_openai_tts(text)
      true -> forward_http_tts(normalize_url(url), text)
    end
  end

  defp forward_http_tts(url, text) do
    req =
      Req.new()
      |> Req.merge(
        url: url,
        headers: [{"accept", "audio/wav"}, {"content-type", "application/json"}],
        decode_body: false,
        retry: :transient,
        retry_log_level: :warn,
        receive_timeout: 60_000,
        connect_options: [timeout: 5_000]
      )

    case Req.post(req, json: %{text: text}) do
      {:ok, %{status: 200, body: body, headers: headers}} when is_binary(body) ->
        ctype = (Enum.find(headers, fn {k, _} -> String.downcase(k) == "content-type" end) || {"content-type", "audio/wav"}) |> elem(1)
        {:ok, {body, ctype}}
      {:ok, %{status: s, body: b}} -> {:error, {:http_error, s, b}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp forward_openai_tts(text) do
    api_key = System.get_env("OPENAI_API_KEY")
    if api_key in [nil, ""], do: {:error, :missing_api_key}, else: :ok
    model = System.get_env("OPENAI_TTS_MODEL", "gpt-4o-mini-tts")
    voice = System.get_env("OPENAI_TTS_VOICE", "alloy")
    format = System.get_env("OPENAI_TTS_FORMAT", "wav")

    # OpenAI Audio Speech API expects key "format" (not response_format)
    body = %{model: model, voice: voice, input: text, format: format}

    req =
      Req.new()
      |> Req.merge(
        url: "https://api.openai.com/v1/audio/speech",
        headers: [
          {"authorization", "Bearer " <> api_key},
          {"content-type", "application/json"},
          {"accept", "audio/" <> format}
        ],
        decode_body: false,
        retry: :transient,
        retry_log_level: :warn,
        receive_timeout: 60_000,
        connect_options: [timeout: 5_000]
      )

    case Req.post(req, json: body) do
      {:ok, %{status: 200, body: audio, headers: headers}} when is_binary(audio) ->
        ctype = (Enum.find(headers, fn {k, _} -> String.downcase(k) == "content-type" end) || {"content-type", "audio/" <> format}) |> elem(1)
        {:ok, {audio, ctype}}
      {:ok, %{status: s, body: b}} -> {:error, {:http_error, s, b}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_ctype(ctype) when is_list(ctype) do
    ctype
    |> List.first()
    |> normalize_ctype()
  end

  defp normalize_ctype(ctype) when is_binary(ctype) and byte_size(ctype) > 0, do: ctype
  defp normalize_ctype(_), do: "audio/wav"
end
