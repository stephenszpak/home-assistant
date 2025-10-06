import Config

if config_env() == :prod do
  openai = System.get_env("OPENAI_API_KEY", nil) ||
    raise "environment variable OPENAI_API_KEY is missing"

  base = System.get_env("HA_BASE_URL", "http://homeassistant.local:8123")
  token = System.get_env("HA_TOKEN", nil)

  config :core,
    openai_api_key: openai,
    ha_base_url: base,
    ha_token: token
else
  config :core,
    openai_api_key: System.get_env("OPENAI_API_KEY", nil),
    ha_base_url: System.get_env("HA_BASE_URL", "http://homeassistant.local:8123"),
    ha_token: System.get_env("HA_TOKEN", nil)
end

