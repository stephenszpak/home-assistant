defmodule Core.Brain do
  @moduledoc """
  OpenAI Chat Completions client using Req.
  """

  require Logger

  @endpoint "https://api.openai.com/v1/chat/completions"

  @doc """
  Replies to a prompt or list of messages via OpenAI Chat Completions.

  Accepts a string or a list of `%{role: string(), content: string()}` maps.
  Returns `{:ok, response_text}` or `{:error, reason}`.
  """
  @spec reply(String.t() | list(map())) :: {:ok, String.t()} | {:error, term()}
  def reply(prompt) when is_binary(prompt) do
    reply([%{role: "user", content: prompt}])
  end

  def reply(messages) when is_list(messages) do
    with {:ok, key} <- fetch_api_key(),
         {:ok, model} <- fetch_model() do
      system = %{
        role: "system",
        content:
          "You are a concise, friendly home assistant for a small touchscreen. Format for glanceable reading: use short sections, line breaks, and simple bullets ('-' or numbered lists). Avoid dense paragraphs and heavy Markdown styling; prefer plain text with newlines. Keep answers brief unless asked for detail."
      }

      body = %{
        model: model,
        messages: [system | Enum.map(messages, &normalize_msg/1)]
      }

      headers = [
        {"authorization", "Bearer #{key}"},
        {"content-type", "application/json"}
      ]

      req = Req.new(url: @endpoint, headers: headers, finch: Core.Finch)

      case Req.post(req, json: body) do
        {:ok, %{status: 200, body: %{"choices" => [first | _]} = resp}} ->
          content =
            get_in(first, ["message", "content"]) ||
              get_in(resp, ["choices", Access.at(0), "message", "content"]) ||
              ""

          {:ok, content}

        {:ok, %{status: status, body: body}} ->
          Logger.warning("OpenAI non-200 status=#{status}")
          {:error, {:http_error, status, body}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp fetch_api_key do
    case Application.get_env(:core, :openai_api_key) do
      nil -> {:error, :missing_api_key}
      "" -> {:error, :missing_api_key}
      key -> {:ok, key}
    end
  end

  defp fetch_model do
    model = Application.get_env(:core, :openai_model) || System.get_env("OPENAI_MODEL", "gpt-4o-mini")
    {:ok, model}
  end

  defp normalize_msg(%{role: role, content: content}) when is_binary(role) and is_binary(content), do: %{role: role, content: content}
  defp normalize_msg(%{role: role, text: content}) when is_atom(role) and is_binary(content), do: %{role: Atom.to_string(role), content: content}
  defp normalize_msg(%{role: role, text: content}) when is_binary(role) and is_binary(content), do: %{role: role, content: content}
  defp normalize_msg(%{role: role, content: content}) when is_atom(role) and is_binary(content), do: %{role: Atom.to_string(role), content: content}
  defp normalize_msg(other) do
    Logger.debug("normalizing unknown message=#{inspect(other)}")
    %{role: "user", content: to_string(other)}
  end
end
