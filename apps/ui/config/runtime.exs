import Config

if config_env() == :prod do
  secret_key_base = System.get_env("PHX_SECRET_KEY_BASE", nil) ||
    raise "environment variable PHX_SECRET_KEY_BASE is missing"

  live_view_salt = System.get_env("LIVE_VIEW_SALT", nil) ||
    raise "environment variable LIVE_VIEW_SALT is missing"

  port = String.to_integer(System.get_env("PORT", "4000"))

  config :ui, UiWeb.Endpoint,
    http: [ip: {0, 0, 0, 0}, port: port],
    secret_key_base: secret_key_base,
    live_view: [signing_salt: live_view_salt]
end
