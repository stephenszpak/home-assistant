defmodule UiWeb.ErrorJSON do
  @moduledoc false

  def render("404.json", _assigns), do: %{error: %{status: 404, message: "Not Found"}}
  def render("500.json", _assigns), do: %{error: %{status: 500, message: "Server Error"}}
  def render(_template, _assigns), do: %{error: %{status: 500, message: "Error"}}
end

