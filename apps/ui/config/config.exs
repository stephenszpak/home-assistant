import Config

config :ui, UiWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4000],
  url: [host: "0.0.0.0", port: 4000],
  render_errors: [view: UiWeb.ErrorHTML, accepts: ~w(html json), layout: false],
  pubsub_server: Ui.PubSub,
  live_view: [signing_salt: System.get_env("LIVE_VIEW_SALT", "LV_SIGNING_SALT")],
  secret_key_base: System.get_env("PHX_SECRET_KEY_BASE", String.duplicate("a", 64)),
  check_origin: false

