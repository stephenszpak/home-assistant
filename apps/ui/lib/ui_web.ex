defmodule UiWeb do
  @moduledoc false

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end

  def controller do
    quote do
      use Phoenix.Controller, formats: [:html, :json], layouts: [html: UiWeb.Layouts]
      import Plug.Conn
      import Phoenix.Controller, only: [get_csrf_token: 0]
      alias UiWeb.Router.Helpers, as: Routes
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView, layout: {UiWeb.Layouts, :root}
      alias UiWeb.Router.Helpers, as: Routes
      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent
      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component
      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      import Phoenix.HTML
      import Phoenix.LiveView.Helpers
      import Phoenix.Component
      import UiWeb.WeatherComponents
      import UiWeb.AnswerCard
      import UiWeb.PromptBanner
    end
  end
end
