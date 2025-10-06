defmodule Core.BrainTest do
  use ExUnit.Case, async: true

  test "reply/1 returns error when API key missing" do
    original = Application.get_env(:core, :openai_api_key)
    try do
      Application.put_env(:core, :openai_api_key, nil)
      assert {:error, :missing_api_key} = Core.Brain.reply("hello")
    after
      Application.put_env(:core, :openai_api_key, original)
    end
  end
end

