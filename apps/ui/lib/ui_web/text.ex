defmodule UiWeb.Text do
  @moduledoc false

  @doc """
  Lightly normalize assistant text for glanceable display:
  - Strip bold markers **...**
  - Insert line breaks before bullets ("- ") and numbered steps ("1. ") when inline
  - Preserve existing newlines
  """
  def clean(text) when is_binary(text) do
    text
    |> strip_bold()
    |> break_bullets()
    |> break_numbers()
    |> squeeze_spaces()
  end

  def clean(other), do: to_string(other)

  defp strip_bold(t), do: Regex.replace(~r/\*\*(.*?)\*\*/s, t, "\1")

  # Replace space-dash-space with newline-dash-space when not already preceded by a newline
  defp break_bullets(t), do: Regex.replace(~r/(?<!\n)\s-\s/, t, "\n- ")

  # Insert newline before numbered items like " 1. " if not already on a new line
  defp break_numbers(t), do: Regex.replace(~r/(?<!\n)\s(\d+)\.\s/, t, "\n\\1. ")

  defp squeeze_spaces(t), do: Regex.replace(~r/[ \t]+\n/, t, "\n")
end

