defmodule RankEverythingWeb.Router do
  use RankEverythingWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {RankEverythingWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", RankEverythingWeb do
    pipe_through :browser

    live "/", HomeLive
    live "/rank/:id", RankingLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", RankEverythingWeb do
  #   pipe_through :api
  # end
end
