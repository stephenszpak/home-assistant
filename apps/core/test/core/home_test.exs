defmodule Core.HomeTest do
  use ExUnit.Case, async: true

  test "toggle/1 returns not_configured when missing token" do
    original_base = Application.get_env(:core, :ha_base_url)
    original_token = Application.get_env(:core, :ha_token)
    try do
      Application.put_env(:core, :ha_base_url, "http://example.invalid")
      Application.put_env(:core, :ha_token, nil)
      assert {:error, :not_configured} = Core.Home.toggle("light.kitchen")
    after
      Application.put_env(:core, :ha_base_url, original_base)
      Application.put_env(:core, :ha_token, original_token)
    end
  end
end

