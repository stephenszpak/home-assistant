defmodule UiWeb.ErrorHTML do
  use Phoenix.Component

  def render("404.html", assigns) when is_map(assigns), do: ~H"""
  Page not found
  """

  def render("500.html", assigns) when is_map(assigns), do: ~H"""
  Server error
  """

  def render(_template, assigns) when is_map(assigns), do: ~H"""
  Error
  """
end
