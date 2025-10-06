import Config

# Umbrella-wide defaults

# UI Endpoint defaults (can be overridden by apps/ui/config/*)
config :ui, UiWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4000],
  url: [host: "0.0.0.0", port: 4000],
  secret_key_base: System.get_env("PHX_SECRET_KEY_BASE", String.duplicate("a", 64)),
  live_view: [signing_salt: System.get_env("LIVE_VIEW_SALT", "LV_SIGNING_SALT")],
  check_origin: false,
  render_errors: [view: UiWeb.ErrorHTML, accepts: ~w(html json), layout: false],
  pubsub_server: Ui.PubSub

# Core defaults
config :core,
  openai_api_key: System.get_env("OPENAI_API_KEY"),
  ha_base_url: System.get_env("HA_BASE_URL", "http://homeassistant.local:8123"),
  ha_token: System.get_env("HA_TOKEN")

# Import each child app's config explicitly (workaround for wildcard resolution in some environments)
for conf <- Path.wildcard(Path.expand("../apps/*/config/config.exs", __DIR__)) do
  import_config conf
end
