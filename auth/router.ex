defmodule RedditCloneWeb.Router do
  use RedditCloneWeb, :router

  import RedditCloneWeb.UserAuth

  # ----------------------------------------------------------------
  # Pipeline定義
  # ----------------------------------------------------------------

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {RedditCloneWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user          # 全リクエストでユーザーを取得
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # ----------------------------------------------------------------
  # セッション操作（通常のコントローラー）
  # ログイン・ログアウトはPlugレイヤーで処理する必要がある
  # ----------------------------------------------------------------

  scope "/", RedditCloneWeb do
    pipe_through [:browser]

    # ログイン処理（LiveViewからリダイレクトされてくる）
    get "/session", SessionController, :create
    delete "/logout", SessionController, :delete
  end

  # ----------------------------------------------------------------
  # 未ログインでもアクセスできるルート
  # ----------------------------------------------------------------

  scope "/", RedditCloneWeb do
    pipe_through [:browser, :redirect_if_authenticated]

    live "/register", RegisterLive
    live "/login",    LoginLive
  end

  scope "/", RedditCloneWeb do
    pipe_through [:browser]

    # Subredditページ（未ログインでも見られる）
    live "/r/:name",          SubredditLive
    live "/r/:name/:post_id", PostLive

    # ユーザープロフィール（未ログインでも見られる）
    live "/u/:username", ProfileLive

    # 検索（未ログインでも見られる）
    live "/search", SearchLive
  end

  # ----------------------------------------------------------------
  # ログインが必要なルート
  # ----------------------------------------------------------------

  scope "/", RedditCloneWeb do
    pipe_through [:browser, :require_auth]

    # ホームFeed
    live "/", HomeFeedLive

    # コミュニティ作成
    live "/subreddits/new", NewSubredditLive

    # 投稿作成
    live "/r/:name/submit", NewPostLive
  end
end
