defmodule UiWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :ui

  # Serve static files (assets built by esbuild/tailwind should be under priv/static)
  plug Plug.Static,
    at: "/",
    from: :ui,
    gzip: false,
    only: ~w(assets fonts images favicon.ico robots.txt)

  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
  end

  @lv_salt (
              cfg = Application.compile_env(:ui, UiWeb.Endpoint, []);
              (Keyword.get(cfg, :live_view, []) |> Keyword.get(:signing_salt)) || "LV_SIGNING_SALT"
            )

  @session_options [
    store: :cookie,
    key: "_ui_key",
    signing_salt: @lv_salt
  ]

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug UiWeb.Router

  # Channels for general websocket use (e.g., STT streaming)
  socket "/socket", UiWeb.UserSocket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: false
end
