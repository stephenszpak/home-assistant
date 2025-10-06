defmodule Core.Brain do
  @moduledoc """
  Wrapper for OpenAI calls (stubbed). Uses Finch + Jason when implemented.
  """

  require Logger

  @spec chat(list(map())) :: {:ok, String.t()} | {:error, term()}
  def chat(messages) when is_list(messages) do
    if api_key() in [nil, ""] do
      Logger.warning("OPENAI_API_KEY not set; returning stubbed response")
      {:ok, "(stub) I cannot talk to OpenAI right now."}
    else
      # Placeholder: implement HTTP request to OpenAI Chat Completions
      {:ok, "(stub) OpenAI response would be here."}
    end
  end

  defp api_key, do: Application.get_env(:core, :openai_api_key)
end

