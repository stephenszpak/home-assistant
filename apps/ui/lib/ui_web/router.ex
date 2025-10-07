defmodule UiWeb.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {UiWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", UiWeb do
    pipe_through :browser
    live "/", HomeLive, :index
  end

  scope "/api", UiWeb do
    pipe_through :api
    post "/stt", ApiController, :stt
    post "/tts", ApiController, :tts
  end
end
