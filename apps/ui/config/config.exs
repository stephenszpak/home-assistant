import Config

# Ensure a valid dev/test secret_key_base even if .env provides a short value
dev_secret_key_base =
  case System.get_env("PHX_SECRET_KEY_BASE") do
    nil -> String.duplicate("a", 64)
    v when is_binary(v) and byte_size(v) >= 64 -> v
    _short -> String.duplicate("a", 64)
  end

config :ui, UiWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4000],
  url: [host: "0.0.0.0", port: 4000],
  render_errors: [formats: [html: UiWeb.ErrorHTML, json: UiWeb.ErrorJSON], layout: false],
  pubsub_server: Ui.PubSub,
  live_view: [signing_salt: System.get_env("LIVE_VIEW_SALT", "LV_SIGNING_SALT")],
  secret_key_base: dev_secret_key_base,
  check_origin: false
