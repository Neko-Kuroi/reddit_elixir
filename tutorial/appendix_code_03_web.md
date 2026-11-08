# 全コード付録 3　Web 層（認証＋LiveView＋コンポーネント）

> **このファイルは自動生成です。** 生成スクリプト `~/workspace/reddit_clone_audit/generate_code_appendix.py` が、
> 正本のコードファイル（`~/workspace/reddit_clone_fixed/` 内）から全文を機械的に転記して作りました。
> **正本はコードファイルそのもの**であり、この付録は「すべてのコードがチュートリアル側に収録されている」
> ことを保証するための再録です。コードを直すときは正本を直し、この付録は再生成してください。
>
> 対応する章: 第5章（認証）、第6章（LiveView）、第7章（コンポーネント）、第8章（root レイアウト）

---

## auth/login_live.ex（RedditCloneWeb.LoginLive）

対応: 第5章（router.ex を含む）。正本: `auth/login_live.ex`

```elixir
defmodule RedditCloneWeb.LoginLive do
  use RedditCloneWeb, :live_view

  on_mount {RedditCloneWeb.UserAuth, :redirect_if_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "ログイン")
     |> assign(:form, to_form(%{}, as: "user"))}
  end

  @impl true
  def handle_event("login", %{"user" => %{"email" => email, "password" => password}}, socket) do
    case RedditClone.Accounts.login_user(email, password) do
      {:ok, user} ->
        # 成功 → セッションへ保存してホームへ
        # セッションへの書き込みはPlugレイヤーで行うため
        # ここではリダイレクト先を指示するだけ
        token =
          Phoenix.Token.sign(
            RedditCloneWeb.Endpoint,
            "user_auth",
            user.id
          )

        {:noreply,
         socket
         |> put_flash(:info, "ログインしました")
         |> redirect(to: "/session?token=#{token}")}

      {:error, :invalid_credentials} ->
        # 失敗 → 理由は曖昧にする
        {:noreply,
         socket
         |> put_flash(:error, "メールアドレスまたはパスワードが違います")
         |> assign(:form, to_form(%{"email" => email}, as: "user"))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-md mx-auto mt-16 p-6">
      <h1 class="text-2xl font-bold mb-6">ログイン</h1>

      <.form for={@form} phx-submit="login">

        <%!-- メールアドレス --%>
        <div class="mb-4">
          <.input
            field={@form[:email]}
            type="email"
            label="メールアドレス"
            placeholder="例: alice@example.com"
          />
        </div>

        <%!-- パスワード --%>
        <div class="mb-6">
          <.input
            field={@form[:password]}
            type="password"
            label="パスワード"
          />
        </div>

        <.button type="submit" class="w-full">
          ログイン
        </.button>

      </.form>

      <p class="mt-4 text-center text-sm">
        アカウントをお持ちでないですか？
        <.link navigate="/register" class="text-blue-500 hover:underline">
          新規登録
        </.link>
      </p>
    </div>
    """
  end
end
```

## auth/register_live.ex（RedditCloneWeb.RegisterLive）

対応: 第5章（router.ex を含む）。正本: `auth/register_live.ex`

```elixir
defmodule RedditCloneWeb.RegisterLive do
  use RedditCloneWeb, :live_view

  alias RedditClone.Accounts
  alias RedditClone.Accounts.User

  on_mount {RedditCloneWeb.UserAuth, :redirect_if_authenticated}

  @impl true
  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%User{})

    {:ok,
     socket
     |> assign(:page_title, "ユーザー登録")
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"user" => params}, socket) do
    # 入力中にリアルタイムでバリデーションする
    changeset =
      %User{}
      |> User.registration_changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("register", %{"user" => params}, socket) do
    case Accounts.register_user(params) do
      {:ok, user} ->
        # 登録成功 → login_live と同様に Token 経由で自動ログイン
        token =
          Phoenix.Token.sign(
            RedditCloneWeb.Endpoint,
            "user_auth",
            user.id
          )

        {:noreply,
         socket
         |> put_flash(:info, "登録が完了しました！")
         |> redirect(to: "/session?token=#{token}")}

      {:error, changeset} ->
        # 登録失敗 → エラーを表示
        {:noreply, assign_form(socket, changeset)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-md mx-auto mt-16 p-6">
      <h1 class="text-2xl font-bold mb-6">アカウントを作成</h1>

      <.form for={@form} phx-change="validate" phx-submit="register">

        <%!-- ユーザー名 --%>
        <div class="mb-4">
          <.input
            field={@form[:username]}
            label="ユーザー名"
            placeholder="例: alice"
          />
        </div>

        <%!-- メールアドレス --%>
        <div class="mb-4">
          <.input
            field={@form[:email]}
            type="email"
            label="メールアドレス"
            placeholder="例: alice@example.com"
          />
        </div>

        <%!-- パスワード --%>
        <div class="mb-6">
          <.input
            field={@form[:password]}
            type="password"
            label="パスワード（8文字以上）"
          />
        </div>

        <.button type="submit" class="w-full">
          登録する
        </.button>

      </.form>

      <p class="mt-4 text-center text-sm">
        すでにアカウントをお持ちですか？
        <.link navigate="/login" class="text-blue-500 hover:underline">
          ログイン
        </.link>
      </p>
    </div>
    """
  end

  defp assign_form(socket, changeset) do
    assign(socket, :form, to_form(changeset, as: "user"))
  end
end
```

## auth/router.ex（RedditCloneWeb.Router）

対応: 第5章（router.ex を含む）。正本: `auth/router.ex`

```elixir
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
```

## auth/session_controller.ex（RedditCloneWeb.SessionController）

対応: 第5章（router.ex を含む）。正本: `auth/session_controller.ex`

```elixir
defmodule RedditCloneWeb.SessionController do
  use RedditCloneWeb, :controller

  alias RedditClone.Accounts
  alias RedditCloneWeb.UserAuth

  # トークンの有効期限（秒）
  # LoginLive で生成してからこのコントローラーに届くまでの時間
  @max_age 60

  @doc """
  LiveViewのログイン成功後にリダイレクトされてくる。
  Phoenix.Token で署名されたトークンを検証し
  正当であれば user_id をセッションに保存してホームへ。
  """
  def create(conn, %{"token" => token}) do
    case Phoenix.Token.verify(
           RedditCloneWeb.Endpoint,
           "user_auth",
           token,
           max_age: @max_age
         ) do
      {:ok, user_id} ->
        # トークンが正当 → ユーザーを取得してセッションに保存
        user = Accounts.get_user!(user_id)
        UserAuth.log_in_user(conn, user)

      {:error, _reason} ->
        # トークンが不正または期限切れ → ログインページへ
        conn
        |> put_flash(:error, "セッションが無効です。もう一度ログインしてください")
        |> redirect(to: "/login")
    end
  end

  @doc """
  ログアウト。セッションを全て削除してログインページへ。
  """
  def delete(conn, _params) do
    conn
    |> put_flash(:info, "ログアウトしました")
    |> UserAuth.log_out_user()
  end
end
```

## auth/user_auth.ex（RedditCloneWeb.UserAuth）

対応: 第5章（router.ex を含む）。正本: `auth/user_auth.ex`

```elixir
defmodule RedditCloneWeb.UserAuth do
  @moduledoc """
  認証関連のPlugとLiveViewヘルパー。
  セッションからユーザーを取得し、ルートを保護する。
  """

  use RedditCloneWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias RedditClone.Accounts

  # セッションのキー名
  @session_key "user_id"

  # ----------------------------------------------------------------
  # Plugs（通常のHTTPリクエスト用）
  # ----------------------------------------------------------------

  @doc """
  セッションからuser_idを取り出し、
  DBからユーザーを取得して conn.assigns に入れる。
  未ログインの場合は current_user: nil になる。
  """
  def fetch_current_user(conn, _opts) do
    user_id = get_session(conn, @session_key)

    current_user =
      if user_id do
        Accounts.get_user!(user_id)
      else
        nil
      end

    assign(conn, :current_user, current_user)
  end

  @doc """
  未ログインのユーザーをログインページへリダイレクトする。
  ログインが必要なルートに付ける。
  """
  def require_auth(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "ログインが必要です")
      |> redirect(to: ~p"/login")
      |> halt()
    end
  end

  @doc """
  すでにログイン済みのユーザーをホームへリダイレクトする。
  登録・ログインページに付ける。
  """
  def redirect_if_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
      |> redirect(to: ~p"/")
      |> halt()
    else
      conn
    end
  end

  # ----------------------------------------------------------------
  # セッション操作
  # ----------------------------------------------------------------

  @doc """
  ログイン成功時にセッションへ user_id を保存する。
  """
  def log_in_user(conn, user, params \\ %{}) do
    conn
    |> renew_session()
    |> put_session(@session_key, user.id)
    |> redirect(to: params["return_to"] || ~p"/")
  end

  @doc """
  ログアウト時にセッションを全て削除する。
  """
  def log_out_user(conn) do
    conn
    |> renew_session()
    |> redirect(to: ~p"/login")
  end

  # セッションの再生成（セッション固定攻撃の防止）
  defp renew_session(conn) do
    delete_csrf_token()

    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  # ----------------------------------------------------------------
  # LiveView用ヘルパー（on_mount）
  # ----------------------------------------------------------------

  @doc """
  LiveViewのマウント時にユーザーを取得する。

  使い方:
    on_mount {RedditCloneWeb.UserAuth, :fetch_current_user}
    on_mount {RedditCloneWeb.UserAuth, :require_auth}
  """
  def on_mount(:fetch_current_user, _params, session, socket) do
    {:cont, mount_current_user(session, socket)}
  end

  def on_mount(:require_auth, _params, session, socket) do
    socket = mount_current_user(session, socket)

    if socket.assigns.current_user do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "ログインが必要です")
        |> Phoenix.LiveView.redirect(to: ~p"/login")

      {:halt, socket}
    end
  end

  def on_mount(:redirect_if_authenticated, _params, session, socket) do
    socket = mount_current_user(session, socket)

    if socket.assigns.current_user do
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
    else
      {:cont, socket}
    end
  end

  # セッションからユーザーを取得してsocketに付ける
  defp mount_current_user(session, socket) do
    current_user =
      case Map.get(session, @session_key) do
        nil -> nil
        user_id -> Accounts.get_user!(user_id)
      end

    Phoenix.Component.assign(socket, :current_user, current_user)
  end
end
```

## live/components/comment_tree.ex（RedditCloneWeb.Components.CommentTree）

対応: 第6〜8章。正本: `live/components/comment_tree.ex`

```elixir
defmodule RedditCloneWeb.Components.CommentTree do
  @moduledoc """
  コメントをネスト構造で再帰的に表示するコンポーネント。
  PostLive から使う。
  """

  use RedditCloneWeb, :html

  import RedditCloneWeb.Helpers

  @max_depth 8

  @doc """
  コメントツリーを表示する。

  ## 属性
    - comments:     表示するコメントのリスト（ツリー構造）
    - current_user: ログイン中のユーザー（nil可）
    - depth:        現在のネスト深さ（デフォルト0）
  """
  attr :comments,     :list,  required: true
  attr :current_user, :map,   default: nil
  attr :depth,        :integer, default: 0

  def comment_tree(assigns) do
    ~H"""
    <div class={depth_class(@depth)}>
      <%= for comment <- @comments do %>
        <.comment_item
          comment={comment}
          current_user={@current_user}
          depth={@depth}
        />
      <% end %>
    </div>
    """
  end

  # 1件のコメントと、その子コメントを表示する
  attr :comment,      :map,     required: true
  attr :current_user, :map,     default: nil
  attr :depth,        :integer, default: 0

  defp comment_item(assigns) do
    ~H"""
    <div class="mb-2">
      <%!-- コメント本体 --%>
      <div class="flex gap-2">

        <%!-- 投票ボタン --%>
        <div class="flex flex-col items-center gap-0.5 pt-1">
          <button
            phx-click="vote_comment"
            phx-value-id={@comment.id}
            phx-value-value="1"
            class="text-gray-300 hover:text-orange-500 text-xs"
          >
            ▲
          </button>
          <span class="text-xs text-gray-500"><%= @comment.score %></span>
          <button
            phx-click="vote_comment"
            phx-value-id={@comment.id}
            phx-value-value="-1"
            class="text-gray-300 hover:text-blue-500 text-xs"
          >
            ▼
          </button>
        </div>

        <%!-- コメント内容 --%>
        <div class="flex-1 border-l-2 border-gray-100 pl-2">

          <%!-- メタ情報 --%>
          <div class="text-xs text-gray-500 mb-1">
            <span class="font-medium text-gray-700">
              u/<%= @comment.author.username %>
            </span>
            • <%= time_ago(@comment.inserted_at) %>
            • <%= @comment.score %> ポイント
          </div>

          <%!-- 本文 --%>
          <p class="text-sm text-gray-800 whitespace-pre-wrap"><%= @comment.body %></p>

          <%!-- アクションボタン --%>
          <div class="flex gap-3 mt-1">
            <%= if @current_user do %>
              <button
                phx-click="reply_to"
                phx-value-id={@comment.id}
                class="text-xs text-gray-400 hover:text-gray-600"
              >
                返信
              </button>
            <% end %>

            <%= if can_delete?(@current_user, @comment) do %>
              <button
                phx-click="delete_comment"
                phx-value-id={@comment.id}
                data-confirm="このコメントを削除しますか？"
                class="text-xs text-red-400 hover:text-red-600"
              >
                削除
              </button>
            <% end %>

            <%= if can_report?(@current_user, @comment) do %>
              <button
                phx-click="open_report_modal"
                phx-value-type="comment"
                phx-value-id={@comment.id}
                class="text-xs text-gray-400 hover:text-gray-600"
              >
                報告
              </button>
            <% end %>
          </div>

        </div>
      </div>

      <%!-- 子コメント（再帰）--%>
      <%= if @comment.replies != [] && @depth < @max_depth do %>
        <div class="ml-6 mt-1">
          <.comment_tree
            comments={@comment.replies}
            current_user={@current_user}
            depth={@depth + 1}
          />
        </div>
      <% end %>

    </div>
    """
  end

  # 深さに応じてインデントを調整する
  defp depth_class(0), do: ""
  defp depth_class(_), do: "border-l border-gray-200 pl-2"

  # 自分のコメントのみ削除できる
  defp can_delete?(nil, _comment), do: false
  defp can_delete?(user, comment),  do: user.id == comment.author_id

  # 自分のコメント以外を報告できる（ログイン必須）
  defp can_report?(nil, _comment), do: false
  defp can_report?(user, comment),  do: user.id != comment.author_id
end
```

## live/components/post_card.ex（RedditCloneWeb.Components.PostCard）

対応: 第6〜8章。正本: `live/components/post_card.ex`

```elixir
defmodule RedditCloneWeb.Components.PostCard do
  @moduledoc """
  Feed上の投稿1件を表示するコンポーネント。
  SubredditLive と HomeFeedLive で共通して使う。
  """

  use RedditCloneWeb, :html

  import RedditCloneWeb.Helpers

  @doc """
  投稿カードを表示する。

  ## 属性
    - post: %Post{} （author をpreloadしておくこと）
    - show_subreddit: true の場合 r/○○ を表示する（ホームFeed用）
  """
  attr :post, :map, required: true
  attr :show_subreddit, :boolean, default: false
  attr :current_user, :map, default: nil

  def post_card(assigns) do
    ~H"""
    <div class="bg-white border border-gray-200 rounded hover:border-gray-400 mb-2 flex">

      <%!-- 左側: 投票エリア --%>
      <div class="bg-gray-50 w-10 flex flex-col items-center py-2 gap-1 rounded-l">
        <button
          phx-click="vote"
          phx-value-id={@post.id}
          phx-value-type="post"
          phx-value-value="1"
          class="text-gray-400 hover:text-orange-500"
        >
          ▲
        </button>
        <span class="text-xs font-bold text-gray-700"><%= @post.score %></span>
        <button
          phx-click="vote"
          phx-value-id={@post.id}
          phx-value-type="post"
          phx-value-value="-1"
          class="text-gray-400 hover:text-blue-500"
        >
          ▼
        </button>
      </div>

      <%!-- 右側: 投稿内容 --%>
      <div class="p-2 flex-1">

        <%!-- タイトル + タイプバッジ --%>
        <div class="flex items-start gap-2">
          <.link
            navigate={post_url(@post)}
            class="text-sm font-medium text-gray-900 hover:underline flex-1"
          >
            <%= @post.title %>
          </.link>

          <%= if @post.type == "link" do %>
            <a
              href={@post.url}
              target="_blank"
              rel="noopener noreferrer"
              class="text-xs text-blue-500 hover:underline whitespace-nowrap"
            >
              <%= domain(@post.url) %> ↗
            </a>
          <% else %>
            <span class="text-xs text-gray-400">text</span>
          <% end %>
        </div>

        <%!-- メタ情報 --%>
        <div class="flex items-center gap-2 mt-1 text-xs text-gray-500">
          <%= if @show_subreddit do %>
            <.link
              navigate={~p"/r/#{@post.subreddit.name}"}
              class="font-medium hover:underline"
            >
              r/<%= @post.subreddit.name %>
            </.link>
            <span>•</span>
          <% end %>

          <span>
            投稿者
            <.link navigate={~p"/u/#{@post.author.username}"} class="hover:underline">
              u/<%= @post.author.username %>
            </.link>
          </span>
          <span>•</span>
          <span><%= time_ago(@post.inserted_at) %></span>
        </div>

        <%!-- コメント数 + 報告ボタン --%>
        <div class="mt-1 flex items-center gap-2">
          <.link
            navigate={post_url(@post)}
            class="text-xs text-gray-500 hover:bg-gray-100 px-1 py-0.5 rounded"
          >
            💬 <%= @post.comment_count || 0 %> コメント
          </.link>

          <%= if @current_user && @current_user.id != @post.author_id do %>
            <button
              phx-click="open_report_modal"
              phx-value-type="post"
              phx-value-id={@post.id}
              class="text-xs text-gray-400 hover:text-gray-600 px-1 py-0.5 rounded hover:bg-gray-100"
            >
              報告
            </button>
          <% end %>
        </div>

      </div>
    </div>
    """
  end

  # 投稿のURLを生成する
  defp post_url(post) do
    "/r/#{post.subreddit.name}/#{post.id}"
  end
end
```

## live/components/report_modal.ex（RedditCloneWeb.Components.ReportModal）

対応: 第6〜8章。正本: `live/components/report_modal.ex`

```elixir
defmodule RedditCloneWeb.Components.ReportModal do
  @moduledoc """
  投稿・コメントへの報告モーダル。
  SubredditLive / PostLive / HomeFeedLive / ProfileLive / SearchLive から使う。
  """

  use RedditCloneWeb, :html

  @reasons [
    {"spam",           "スパム"},
    {"harassment",     "嫌がらせ・ハラスメント"},
    {"hate_speech",    "ヘイトスピーチ"},
    {"misinformation", "誤情報"},
    {"other",          "その他"}
  ]

  @doc """
  報告モーダルを表示する。

  ## 属性
    - report_modal: %{target_type: "post"|"comment", target_id: id} | nil
  """
  attr :report_modal, :map, default: nil

  def report_modal(assigns) do
    assigns = assign(assigns, :reasons, @reasons)

    ~H"""
    <%= if @report_modal do %>
      <%!-- 背景オーバーレイ --%>
      <div
        class="fixed inset-0 bg-black bg-opacity-50 z-40"
        phx-click="close_report_modal"
      />

      <%!-- モーダル本体 --%>
      <div class="fixed inset-0 z-50 flex items-center justify-center p-4">
        <div class="bg-white rounded-lg shadow-xl w-full max-w-md">

          <%!-- ヘッダー --%>
          <div class="flex justify-between items-center p-4 border-b border-gray-200">
            <h2 class="text-lg font-bold">報告する</h2>
            <button
              phx-click="close_report_modal"
              class="text-gray-400 hover:text-gray-600 text-xl"
            >
              ✕
            </button>
          </div>

          <%!-- 理由の選択 --%>
          <div class="p-4">
            <p class="text-sm text-gray-600 mb-3">
              報告する理由を選択してください
            </p>

            <div class="space-y-2">
              <%= for {value, label} <- @reasons do %>
                <button
                  phx-click="submit_report"
                  phx-value-reason={value}
                  phx-value-target_type={@report_modal.target_type}
                  phx-value-target_id={@report_modal.target_id}
                  class="w-full text-left px-4 py-3 rounded border border-gray-200 text-sm hover:bg-gray-50 hover:border-gray-300 transition-colors"
                >
                  <%= label %>
                </button>
              <% end %>
            </div>
          </div>

          <%!-- フッター --%>
          <div class="p-4 border-t border-gray-100">
            <button
              phx-click="close_report_modal"
              class="w-full py-2 text-sm text-gray-500 hover:text-gray-700"
            >
              キャンセル
            </button>
          </div>

        </div>
      </div>
    <% end %>
    """
  end
end
```

## live/helpers.ex（RedditCloneWeb.Helpers）

対応: 第6〜8章。正本: `live/helpers.ex`

```elixir
defmodule RedditCloneWeb.Helpers do
  @moduledoc """
  画面コンポーネント共通のヘルパー関数。
  post_card.ex / comment_tree.ex などから import して使う。
  """

  @doc """
  DateTime を「3時間前」のような相対時間文字列に変換する。

  ## 例
      iex> time_ago(~U[2024-01-01 00:00:00Z])
      "3日前"
  """
  def time_ago(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime)

    cond do
      diff < 60           -> "たった今"
      diff < 3_600        -> "#{div(diff, 60)}分前"
      diff < 86_400       -> "#{div(diff, 3_600)}時間前"
      diff < 86_400 * 30  -> "#{div(diff, 86_400)}日前"
      true                -> "#{div(diff, 86_400 * 30)}ヶ月前"
    end
  end

  @doc """
  URLからドメイン名だけを取り出す。

  ## 例
      iex> domain("https://github.com/elixir-lang/elixir")
      "github.com"

      iex> domain("不正なURL")
      "不正なURL"
  """
  def domain(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{host: host} when is_binary(host) -> host
      _ -> url
    end
  end
  def domain(_), do: ""
end
```

## live/home_feed_live.ex（RedditCloneWeb.HomeFeedLive）

対応: 第6〜8章。正本: `live/home_feed_live.ex`

```elixir
defmodule RedditCloneWeb.HomeFeedLive do
  use RedditCloneWeb, :live_view

  import RedditCloneWeb.Components.PostCard
  import RedditCloneWeb.Components.ReportModal

  alias RedditClone.Communities
  alias RedditClone.Posts
  alias RedditClone.Reports

  on_mount {RedditCloneWeb.UserAuth, :require_auth}

  # ----------------------------------------------------------------
  # mount
  # ----------------------------------------------------------------

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    posts            = Posts.list_home_posts(user.id, "hot", 1)
    joined_subreddits = Communities.list_joined_subreddits(user.id)

    {:ok,
     socket
     |> assign(:page_title, "ホーム")
     |> assign(:posts, posts)
     |> assign(:sort, "hot")
     |> assign(:page, 1)
     |> assign(:has_more?, length(posts) == 25)
     |> assign(:joined_subreddits, joined_subreddits)
     |> assign(:report_modal, nil)}
  end

  # ----------------------------------------------------------------
  # イベント処理
  # ----------------------------------------------------------------

  @impl true
  def handle_event("sort", %{"value" => sort}, socket) do
    user  = socket.assigns.current_user
    posts = Posts.list_home_posts(user.id, sort, 1)

    {:noreply,
     socket
     |> assign(:sort, sort)
     |> assign(:page, 1)
     |> assign(:has_more?, length(posts) == 25)
     |> assign(:posts, posts)}
  end

  def handle_event("load_more", _params, socket) do
    user      = socket.assigns.current_user
    next_page = socket.assigns.page + 1
    new_posts = Posts.list_home_posts(user.id, socket.assigns.sort, next_page)

    {:noreply,
     socket
     |> assign(:page, next_page)
     |> assign(:has_more?, length(new_posts) == 25)
     |> assign(:posts, socket.assigns.posts ++ new_posts)}
  end

  def handle_event("vote", %{"id" => post_id, "value" => value}, socket) do
    value = String.to_integer(value)

    case Posts.vote_post(socket.assigns.current_user.id, post_id, value) do
      {:ok, updated_post} ->
        posts =
          Enum.map(socket.assigns.posts, fn post ->
            if post.id == updated_post.id, do: updated_post, else: post
          end)

        {:noreply, assign(socket, :posts, posts)}

      {:error, :cannot_vote_own_post} ->
        {:noreply, put_flash(socket, :error, "自分の投稿には投票できません")}
    end
  end

  # ----------------------------------------------------------------
  # レンダリング
  # ----------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto px-4 py-4 flex gap-4">

      <%!-- 左サイドバー: 参加中のSubreddit一覧 --%>
      <div class="w-48 shrink-0">
        <div class="bg-white border border-gray-200 rounded p-3">
          <h2 class="text-xs font-bold text-gray-500 uppercase mb-2">参加中</h2>

          <%= if @joined_subreddits == [] do %>
            <p class="text-xs text-gray-400">まだ参加していません</p>
          <% else %>
            <%= for subreddit <- @joined_subreddits do %>
              <.link
                navigate={~p"/r/#{subreddit.name}"}
                class="block text-sm py-1 hover:text-blue-500 truncate"
              >
                r/<%= subreddit.name %>
              </.link>
            <% end %>
          <% end %>

          <div class="border-t border-gray-100 mt-3 pt-3">
            <.link
              navigate={~p"/subreddits/new"}
              class="text-sm text-blue-500 hover:underline"
            >
              ＋ コミュニティを作成
            </.link>
          </div>
        </div>
      </div>

      <%!-- メインカラム --%>
      <div class="flex-1">

        <%!-- ソートタブ --%>
        <div class="bg-white border border-gray-200 rounded p-2 mb-4 flex gap-2">
          <button
            phx-click="sort"
            phx-value-value="hot"
            class={tab_class(@sort, "hot")}
          >
            🔥 Hot
          </button>
          <button
            phx-click="sort"
            phx-value-value="new"
            class={tab_class(@sort, "new")}
          >
            ✨ New
          </button>
        </div>

        <%!-- 投稿一覧 --%>
        <%= if @posts == [] do %>
          <div class="bg-white border border-gray-200 rounded p-8 text-center">
            <p class="text-gray-500 mb-2">まだ投稿がありません</p>
            <p class="text-sm text-gray-400">
              コミュニティに参加して投稿を見てみましょう
            </p>
            <.link
              navigate={~p"/subreddits/new"}
              class="inline-block mt-4 px-4 py-2 bg-blue-500 text-white text-sm rounded hover:bg-blue-600"
            >
              コミュニティを探す
            </.link>
          </div>
        <% else %>
          <%= for post <- @posts do %>
            <.post_card
              post={post}
              show_subreddit={true}
              current_user={@current_user}
            />
          <% end %>

          <%!-- もっと見るボタン --%>
          <%= if @has_more? do %>
            <div class="text-center py-4">
              <button
                phx-click="load_more"
                class="px-6 py-2 border border-gray-300 rounded text-sm text-gray-600 hover:bg-gray-50"
              >
                もっと見る
              </button>
            </div>
          <% end %>
        <% end %>

      </div>

    </div>

    <%!-- 報告モーダル --%>
    <.report_modal report_modal={@report_modal} />
    """
  end

  # ----------------------------------------------------------------
  # ヘルパー
  # ----------------------------------------------------------------

  defp tab_class(current, tab) when current == tab do
    "px-4 py-1 rounded bg-gray-200 font-bold text-sm"
  end
  defp tab_class(_, _) do
    "px-4 py-1 rounded hover:bg-gray-100 text-sm text-gray-600"
  end

  # 報告モーダルを開く
  def handle_event("open_report_modal", %{"type" => type, "id" => id}, socket) do
    case socket.assigns.current_user do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "報告するにはログインが必要です")
         |> redirect(to: "/login")}

      _ ->
        {:noreply, assign(socket, :report_modal, %{target_type: type, target_id: id})}
    end
  end

  # 報告モーダルを閉じる
  def handle_event("close_report_modal", _params, socket) do
    {:noreply, assign(socket, :report_modal, nil)}
  end

  # 報告を送信する
  def handle_event("submit_report", params, socket) do
    attrs = %{
      "reporter_id" => socket.assigns.current_user.id,
      "target_type" => params["target_type"],
      "target_id"   => params["target_id"],
      "reason"      => params["reason"]
    }

    case Reports.create_report(attrs) do
      {:ok, _report} ->
        {:noreply,
         socket
         |> assign(:report_modal, nil)
         |> put_flash(:info, "報告しました。ご協力ありがとうございます。")}

      {:error, :cannot_report_own_content} ->
        {:noreply,
         socket
         |> assign(:report_modal, nil)
         |> put_flash(:error, "自分のコンテンツは報告できません")}

      {:error, :target_not_found} ->
        {:noreply,
         socket
         |> assign(:report_modal, nil)
         |> put_flash(:error, "報告対象が見つかりませんでした")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(:report_modal, nil)
         |> put_flash(:error, "報告に失敗しました。もう一度お試しください。")}
    end
  end
end
```

## live/new_post_live.ex（RedditCloneWeb.NewPostLive）

対応: 第6〜8章。正本: `live/new_post_live.ex`

```elixir
defmodule RedditCloneWeb.NewPostLive do
  use RedditCloneWeb, :live_view

  alias RedditClone.Communities
  alias RedditClone.Posts
  alias RedditClone.Posts.Post

  on_mount {RedditCloneWeb.UserAuth, :require_auth}

  # ----------------------------------------------------------------
  # mount
  # ----------------------------------------------------------------

  @impl true
  def mount(%{"name" => name}, _session, socket) do
    case Communities.get_subreddit_by_name(name) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "r/#{name} は存在しません")
         |> redirect(to: "/")}

      subreddit ->
        changeset = Post.changeset(%Post{}, %{type: "text"})

        {:ok,
         socket
         |> assign(:page_title, "r/#{subreddit.name} に投稿する")
         |> assign(:subreddit, subreddit)
         |> assign(:type, "text")
         |> assign_form(changeset)}
    end
  end

  # ----------------------------------------------------------------
  # イベント処理
  # ----------------------------------------------------------------

  @impl true
  def handle_event("switch_type", %{"type" => type}, socket) do
    # テキスト / リンク タブの切り替え
    changeset = Post.changeset(%Post{}, %{type: type})

    {:noreply,
     socket
     |> assign(:type, type)
     |> assign_form(changeset)}
  end

  def handle_event("validate", %{"post" => params}, socket) do
    changeset =
      %Post{}
      |> Post.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("create", %{"post" => params}, socket) do
    attrs =
      params
      |> Map.put("author_id", socket.assigns.current_user.id)
      |> Map.put("subreddit_id", socket.assigns.subreddit.id)

    case Posts.create_post(attrs) do
      {:ok, post} ->
        {:noreply,
         socket
         |> put_flash(:info, "投稿しました！")
         |> redirect(to: ~p"/r/#{socket.assigns.subreddit.name}/#{post.id}")}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  # ----------------------------------------------------------------
  # レンダリング
  # ----------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto mt-8 px-4">
      <h1 class="text-xl font-bold mb-4">
        r/<%= @subreddit.name %> に投稿する
      </h1>

      <%!-- テキスト / リンク タブ --%>
      <div class="flex border-b border-gray-200 mb-4">
        <button
          phx-click="switch_type"
          phx-value-type="text"
          class={tab_class(@type, "text")}
        >
          📝 テキスト
        </button>
        <button
          phx-click="switch_type"
          phx-value-type="link"
          class={tab_class(@type, "link")}
        >
          🔗 リンク
        </button>
      </div>

      <.form
        for={@form}
        phx-change="validate"
        phx-submit="create"
        class="bg-white border border-gray-200 rounded p-4"
      >
        <%!-- type は hidden で送る --%>
        <input type="hidden" name="post[type]" value={@type} />

        <%!-- タイトル --%>
        <div class="mb-4">
          <.input
            field={@form[:title]}
            label="タイトル"
            placeholder="投稿のタイトルを入力してください"
          />
        </div>

        <%!-- テキスト投稿: 本文 --%>
        <%= if @type == "text" do %>
          <div class="mb-4">
            <.input
              field={@form[:body]}
              type="textarea"
              label="本文"
              placeholder="本文を入力してください（任意）"
              rows="6"
            />
          </div>
        <% end %>

        <%!-- リンク投稿: URL --%>
        <%= if @type == "link" do %>
          <div class="mb-4">
            <.input
              field={@form[:url]}
              type="url"
              label="URL"
              placeholder="https://example.com"
            />
          </div>
        <% end %>

        <div class="flex justify-end gap-2">
          <.link
            navigate={~p"/r/#{@subreddit.name}"}
            class="px-4 py-2 text-sm border border-gray-300 rounded hover:bg-gray-50"
          >
            キャンセル
          </.link>
          <.button type="submit">
            投稿する
          </.button>
        </div>

      </.form>
    </div>
    """
  end

  # ----------------------------------------------------------------
  # ヘルパー
  # ----------------------------------------------------------------

  defp assign_form(socket, changeset) do
    assign(socket, :form, to_form(changeset, as: "post"))
  end

  defp tab_class(current, tab) when current == tab do
    "px-6 py-2 text-sm font-bold border-b-2 border-blue-500 text-blue-500"
  end
  defp tab_class(_, _) do
    "px-6 py-2 text-sm text-gray-500 hover:text-gray-700"
  end
end
```

## live/new_subreddit_live.ex（RedditCloneWeb.NewSubredditLive）

対応: 第6〜8章。正本: `live/new_subreddit_live.ex`

```elixir
defmodule RedditCloneWeb.NewSubredditLive do
  use RedditCloneWeb, :live_view

  alias RedditClone.Communities
  alias RedditClone.Communities.Subreddit

  on_mount {RedditCloneWeb.UserAuth, :require_auth}

  # ----------------------------------------------------------------
  # mount
  # ----------------------------------------------------------------

  @impl true
  def mount(_params, _session, socket) do
    changeset = Subreddit.changeset(%Subreddit{}, %{})

    {:ok,
     socket
     |> assign(:page_title, "コミュニティを作成")
     |> assign_form(changeset)}
  end

  # ----------------------------------------------------------------
  # イベント処理
  # ----------------------------------------------------------------

  @impl true
  def handle_event("validate", %{"subreddit" => params}, socket) do
    changeset =
      %Subreddit{}
      |> Subreddit.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("create", %{"subreddit" => params}, socket) do
    attrs = Map.put(params, "owner_id", socket.assigns.current_user.id)

    case Communities.create_subreddit(attrs) do
      {:ok, subreddit} ->
        {:noreply,
         socket
         |> put_flash(:info, "r/#{subreddit.name} を作成しました！")
         |> redirect(to: ~p"/r/#{subreddit.name}")}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  # ----------------------------------------------------------------
  # レンダリング
  # ----------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-lg mx-auto mt-12 px-4">
      <h1 class="text-2xl font-bold mb-6">コミュニティを作成</h1>

      <.form
        for={@form}
        phx-change="validate"
        phx-submit="create"
        class="bg-white border border-gray-200 rounded p-6"
      >

        <%!-- コミュニティ名 --%>
        <div class="mb-4">
          <.input
            field={@form[:name]}
            label="コミュニティ名"
            placeholder="例: elixir"
          />
          <p class="text-xs text-gray-400 mt-1">
            r/<%= if @form[:name].value != "", do: @form[:name].value, else: "○○" %>
            ・英数字とアンダースコアのみ・3〜21文字
          </p>
        </div>

        <%!-- 説明 --%>
        <div class="mb-6">
          <.input
            field={@form[:description]}
            type="textarea"
            label="説明（任意）"
            placeholder="このコミュニティは何について話す場所ですか？"
            rows="3"
          />
        </div>

        <.button type="submit" class="w-full">
          コミュニティを作成する
        </.button>

      </.form>
    </div>
    """
  end

  # ----------------------------------------------------------------
  # ヘルパー
  # ----------------------------------------------------------------

  defp assign_form(socket, changeset) do
    assign(socket, :form, to_form(changeset, as: "subreddit"))
  end
end
```

## live/post_live.ex（RedditCloneWeb.PostLive）

対応: 第6〜8章。正本: `live/post_live.ex`

```elixir
defmodule RedditCloneWeb.PostLive do
  use RedditCloneWeb, :live_view

  import RedditCloneWeb.Components.CommentTree
  import RedditCloneWeb.Components.ReportModal

  alias RedditClone.Posts
  alias RedditClone.Comments
  alias RedditClone.Comments.Comment
  alias RedditClone.Reports

  on_mount {RedditCloneWeb.UserAuth, :fetch_current_user}

  # ----------------------------------------------------------------
  # mount
  # ----------------------------------------------------------------

  @impl true
  def mount(%{"post_id" => post_id}, _session, socket) do
    case Posts.get_post(post_id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "投稿が見つかりません")
         |> redirect(to: "/")}

      post ->
        comments     = Comments.list_comments(post_id)
        comment_form = build_comment_form()

        {:ok,
         socket
         |> assign(:page_title, post.title)
         |> assign(:post, post)
         |> assign(:comments, comments)
         |> assign(:comment_form, comment_form)
         |> assign(:reply_to, nil)
         |> assign(:report_modal, nil)}
    end
  end

  # ----------------------------------------------------------------
  # イベント処理
  # ----------------------------------------------------------------

  @impl true

  # 投稿への投票
  def handle_event("vote", %{"id" => post_id, "value" => value}, socket) do
    case socket.assigns.current_user do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "投票するにはログインが必要です")
         |> redirect(to: "/login")}

      user ->
        value = String.to_integer(value)

        case Posts.vote_post(user.id, post_id, value) do
          {:ok, updated_post} ->
            {:noreply, assign(socket, :post, updated_post)}

          {:error, :cannot_vote_own_post} ->
            {:noreply, put_flash(socket, :error, "自分の投稿には投票できません")}
        end
    end
  end

  # コメントへの投票
  def handle_event("vote_comment", %{"id" => comment_id, "value" => value}, socket) do
    case socket.assigns.current_user do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "投票するにはログインが必要です")
         |> redirect(to: "/login")}

      user ->
        value = String.to_integer(value)

        case Comments.vote_comment(user.id, comment_id, value) do
          {:ok, _updated} ->
            # コメントツリーを再取得して更新
            comments = Comments.list_comments(socket.assigns.post.id)
            {:noreply, assign(socket, :comments, comments)}

          {:error, :cannot_vote_own_comment} ->
            {:noreply, put_flash(socket, :error, "自分のコメントには投票できません")}
        end
    end
  end

  # 返信ボタン → reply_to をセット
  def handle_event("reply_to", %{"id" => comment_id}, socket) do
    comment = Comments.get_comment!(comment_id)
    form    = build_comment_form(%{parent_id: comment_id})

    {:noreply,
     socket
     |> assign(:reply_to, comment)
     |> assign(:comment_form, form)}
  end

  # 返信キャンセル
  def handle_event("cancel_reply", _params, socket) do
    {:noreply,
     socket
     |> assign(:reply_to, nil)
     |> assign(:comment_form, build_comment_form())}
  end

  # コメント投稿
  def handle_event("create_comment", %{"comment" => params}, socket) do
    case socket.assigns.current_user do
      nil ->
        {:noreply, redirect(socket, to: "/login")}

      user ->
        attrs =
          params
          |> Map.put("author_id", user.id)
          |> Map.put("post_id", socket.assigns.post.id)

        case Comments.create_comment(attrs) do
          {:ok, _comment} ->
            # コメント一覧を再取得
            comments = Comments.list_comments(socket.assigns.post.id)

            {:noreply,
             socket
             |> assign(:comments, comments)
             |> assign(:reply_to, nil)
             |> assign(:comment_form, build_comment_form())}

          {:error, changeset} ->
            {:noreply, assign(socket, :comment_form, to_form(changeset, as: "comment"))}
        end
    end
  end

  # コメント削除
  def handle_event("delete_comment", %{"id" => comment_id}, socket) do
    case socket.assigns.current_user do
      nil ->
        {:noreply, redirect(socket, to: "/login")}

      user ->
        Comments.delete_comment(comment_id, user.id, socket.assigns.post.subreddit_id)
        comments = Comments.list_comments(socket.assigns.post.id)
        {:noreply, assign(socket, :comments, comments)}
    end
  end

  # 投稿削除
  def handle_event("delete_post", _params, socket) do
    case socket.assigns.current_user do
      nil ->
        {:noreply, redirect(socket, to: "/login")}

      user ->
        post = socket.assigns.post

        case Posts.delete_post(post.id, user.id, post.subreddit) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, "投稿を削除しました")
             |> redirect(to: ~p"/r/#{post.subreddit.name}")}

          {:error, :unauthorized} ->
            {:noreply, put_flash(socket, :error, "削除する権限がありません")}
        end
    end
  end

  # ----------------------------------------------------------------
  # レンダリング
  # ----------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto px-4 py-4">

      <%!-- 投稿本体 --%>
      <div class="bg-white border border-gray-200 rounded p-4 mb-4">

        <%!-- 投票 + タイトル --%>
        <div class="flex gap-3">
          <div class="flex flex-col items-center gap-1">
            <button
              phx-click="vote"
              phx-value-id={@post.id}
              phx-value-value="1"
              class="text-gray-400 hover:text-orange-500"
            >
              ▲
            </button>
            <span class="text-sm font-bold"><%= @post.score %></span>
            <button
              phx-click="vote"
              phx-value-id={@post.id}
              phx-value-value="-1"
              class="text-gray-400 hover:text-blue-500"
            >
              ▼
            </button>
          </div>

          <div class="flex-1">
            <h1 class="text-xl font-bold text-gray-900 mb-1">
              <%= @post.title %>
            </h1>

            <%!-- メタ情報 --%>
            <div class="text-xs text-gray-500 mb-3 flex gap-2">
              <.link navigate={~p"/r/#{@post.subreddit.name}"} class="hover:underline font-medium">
                r/<%= @post.subreddit.name %>
              </.link>
              <span>•</span>
              <span>
                u/<.link navigate={~p"/u/#{@post.author.username}"} class="hover:underline">
                  <%= @post.author.username %>
                </.link>
              </span>
            </div>

            <%!-- 本文（テキスト投稿）--%>
            <%= if @post.type == "text" && @post.body do %>
              <p class="text-sm text-gray-800 whitespace-pre-wrap mb-3">
                <%= @post.body %>
              </p>
            <% end %>

            <%!-- URL（リンク投稿）--%>
            <%= if @post.type == "link" do %>
              <a
                href={@post.url}
                target="_blank"
                rel="noopener noreferrer"
                class="text-sm text-blue-500 hover:underline break-all"
              >
                <%= @post.url %> ↗
              </a>
            <% end %>

            <%!-- 削除ボタン（本人のみ）--%>
            <%= if @current_user && @current_user.id == @post.author_id do %>
              <button
                phx-click="delete_post"
                data-confirm="この投稿を削除しますか？"
                class="text-xs text-red-400 hover:text-red-600 mt-2"
              >
                削除
              </button>
            <% end %>
          </div>
        </div>
      </div>

      <%!-- コメント投稿フォーム --%>
      <%= if @current_user do %>
        <div class="bg-white border border-gray-200 rounded p-4 mb-4">

          <%= if @reply_to do %>
            <div class="text-xs text-gray-500 mb-2 flex justify-between">
              <span>u/<%= @reply_to.author.username %> への返信</span>
              <button phx-click="cancel_reply" class="hover:text-gray-700">
                キャンセル
              </button>
            </div>
          <% else %>
            <p class="text-sm font-medium mb-2">コメントを追加</p>
          <% end %>

          <.form for={@comment_form} phx-submit="create_comment">
            <input type="hidden" name="comment[parent_id]" value={@reply_to && @reply_to.id} />

            <textarea
              name="comment[body]"
              rows="4"
              placeholder="コメントを入力してください"
              class="w-full border border-gray-300 rounded p-2 text-sm resize-none focus:outline-none focus:border-blue-400"
            ></textarea>

            <div class="flex justify-end mt-2">
              <.button type="submit" class="text-sm px-4 py-1">
                投稿する
              </.button>
            </div>
          </.form>
        </div>
      <% end %>

      <%!-- コメント一覧 --%>
      <div class="bg-white border border-gray-200 rounded p-4">
        <%= if @comments == [] do %>
          <p class="text-gray-400 text-sm text-center py-4">
            まだコメントはありません。最初のコメントを投稿しましょう！
          </p>
        <% else %>
          <.comment_tree
            comments={@comments}
            current_user={@current_user}
          />
        <% end %>
      </div>

    </div>

    <%!-- 報告モーダル --%>
    <.report_modal report_modal={@report_modal} />
    """
  end

  # ----------------------------------------------------------------
  # ヘルパー
  # ----------------------------------------------------------------

  defp build_comment_form(attrs \\ %{}) do
    %Comment{}
    |> Comment.changeset(attrs)
    |> to_form(as: "comment")
  end

  # 報告モーダルを開く
  def handle_event("open_report_modal", %{"type" => type, "id" => id}, socket) do
    case socket.assigns.current_user do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "報告するにはログインが必要です")
         |> redirect(to: "/login")}

      _ ->
        {:noreply, assign(socket, :report_modal, %{target_type: type, target_id: id})}
    end
  end

  # 報告モーダルを閉じる
  def handle_event("close_report_modal", _params, socket) do
    {:noreply, assign(socket, :report_modal, nil)}
  end

  # 報告を送信する
  def handle_event("submit_report", params, socket) do
    attrs = %{
      "reporter_id" => socket.assigns.current_user.id,
      "target_type" => params["target_type"],
      "target_id"   => params["target_id"],
      "reason"      => params["reason"]
    }

    case Reports.create_report(attrs) do
      {:ok, _report} ->
        {:noreply,
         socket
         |> assign(:report_modal, nil)
         |> put_flash(:info, "報告しました。ご協力ありがとうございます。")}

      {:error, :cannot_report_own_content} ->
        {:noreply,
         socket
         |> assign(:report_modal, nil)
         |> put_flash(:error, "自分のコンテンツは報告できません")}

      {:error, :target_not_found} ->
        {:noreply,
         socket
         |> assign(:report_modal, nil)
         |> put_flash(:error, "報告対象が見つかりませんでした")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(:report_modal, nil)
         |> put_flash(:error, "報告に失敗しました。もう一度お試しください。")}
    end
  end
end
```

## live/profile_live.ex（RedditCloneWeb.ProfileLive）

対応: 第6〜8章。正本: `live/profile_live.ex`

```elixir
defmodule RedditCloneWeb.ProfileLive do
  use RedditCloneWeb, :live_view

  import RedditCloneWeb.Components.PostCard
  import RedditCloneWeb.Components.ReportModal

  alias RedditClone.Accounts
  alias RedditClone.Posts
  alias RedditClone.Reports

  on_mount {RedditCloneWeb.UserAuth, :fetch_current_user}

  # ----------------------------------------------------------------
  # mount
  # ----------------------------------------------------------------

  @impl true
  def mount(%{"username" => username}, _session, socket) do
    case Accounts.get_user_by_username(username) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "u/#{username} は存在しません")
         |> redirect(to: "/")}

      profile_user ->
        posts = Posts.list_user_posts(profile_user.id, 1)

        {:ok,
         socket
         |> assign(:page_title, "u/#{profile_user.username}")
         |> assign(:profile_user, profile_user)
         |> assign(:posts, posts)
         |> assign(:page, 1)
         |> assign(:has_more?, length(posts) == 25)
         |> assign(:report_modal, nil)}
    end
  end

  # ----------------------------------------------------------------
  # イベント処理
  # ----------------------------------------------------------------

  @impl true
  def handle_event("load_more", _params, socket) do
    next_page = socket.assigns.page + 1
    new_posts = Posts.list_user_posts(socket.assigns.profile_user.id, next_page)

    {:noreply,
     socket
     |> assign(:page, next_page)
     |> assign(:has_more?, length(new_posts) == 25)
     |> assign(:posts, socket.assigns.posts ++ new_posts)}
  end

  def handle_event("vote", %{"id" => post_id, "value" => value}, socket) do
    case socket.assigns.current_user do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "投票するにはログインが必要です")
         |> redirect(to: "/login")}

      user ->
        value = String.to_integer(value)

        case Posts.vote_post(user.id, post_id, value) do
          {:ok, updated_post} ->
            posts =
              Enum.map(socket.assigns.posts, fn post ->
                if post.id == updated_post.id, do: updated_post, else: post
              end)

            {:noreply, assign(socket, :posts, posts)}

          {:error, :cannot_vote_own_post} ->
            {:noreply, put_flash(socket, :error, "自分の投稿には投票できません")}
        end
    end
  end

  # ----------------------------------------------------------------
  # レンダリング
  # ----------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto px-4 py-6">

      <%!-- ユーザー情報カード --%>
      <div class="bg-white border border-gray-200 rounded p-6 mb-4">

        <div class="flex items-start justify-between">
          <div>
            <h1 class="text-2xl font-bold text-gray-900">
              u/<%= @profile_user.username %>
            </h1>
            <p class="text-sm text-gray-400 mt-1">
              <%= joined_at(@profile_user.inserted_at) %> に登録
            </p>
          </div>
        </div>

        <%!-- Karma --%>
        <div class="flex gap-6 mt-4 pt-4 border-t border-gray-100">
          <div class="text-center">
            <p class="text-xl font-bold text-gray-800">
              <%= format_karma(@profile_user.post_karma) %>
            </p>
            <p class="text-xs text-gray-400">Post Karma</p>
          </div>
          <div class="text-center">
            <p class="text-xl font-bold text-gray-800">
              <%= format_karma(@profile_user.comment_karma) %>
            </p>
            <p class="text-xs text-gray-400">Comment Karma</p>
          </div>
          <div class="text-center">
            <p class="text-xl font-bold text-gray-800">
              <%= format_karma(@profile_user.post_karma + @profile_user.comment_karma) %>
            </p>
            <p class="text-xs text-gray-400">合計 Karma</p>
          </div>
        </div>

      </div>

      <%!-- 投稿一覧 --%>
      <h2 class="text-sm font-bold text-gray-500 uppercase mb-3">投稿</h2>

      <%= if @posts == [] do %>
        <div class="bg-white border border-gray-200 rounded p-8 text-center">
          <p class="text-gray-400 text-sm">まだ投稿がありません</p>
        </div>
      <% else %>
        <%= for post <- @posts do %>
          <.post_card
            post={post}
            show_subreddit={true}
            current_user={@current_user}
          />
        <% end %>

        <%!-- もっと見るボタン --%>
        <%= if @has_more? do %>
          <div class="text-center py-4">
            <button
              phx-click="load_more"
              class="px-6 py-2 border border-gray-300 rounded text-sm text-gray-600 hover:bg-gray-50"
            >
              もっと見る
            </button>
          </div>
        <% end %>
      <% end %>

    </div>

    <%!-- 報告モーダル --%>
    <.report_modal report_modal={@report_modal} />
    """
  end

  # ----------------------------------------------------------------
  # ヘルパー
  # ----------------------------------------------------------------

  # Karma を読みやすい形式にする（1000以上は k 表記）
  defp format_karma(karma) when karma >= 1000 do
    "#{Float.round(karma / 1000, 1)}k"
  end
  defp format_karma(karma), do: to_string(karma)

  # 登録日を「2024年1月」形式で表示する
  defp joined_at(datetime) do
    "#{datetime.year}年#{datetime.month}月"
  end

  # 報告モーダルを開く
  def handle_event("open_report_modal", %{"type" => type, "id" => id}, socket) do
    case socket.assigns.current_user do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "報告するにはログインが必要です")
         |> redirect(to: "/login")}

      _ ->
        {:noreply, assign(socket, :report_modal, %{target_type: type, target_id: id})}
    end
  end

  # 報告モーダルを閉じる
  def handle_event("close_report_modal", _params, socket) do
    {:noreply, assign(socket, :report_modal, nil)}
  end

  # 報告を送信する
  def handle_event("submit_report", params, socket) do
    attrs = %{
      "reporter_id" => socket.assigns.current_user.id,
      "target_type" => params["target_type"],
      "target_id"   => params["target_id"],
      "reason"      => params["reason"]
    }

    case Reports.create_report(attrs) do
      {:ok, _report} ->
        {:noreply,
         socket
         |> assign(:report_modal, nil)
         |> put_flash(:info, "報告しました。ご協力ありがとうございます。")}

      {:error, :cannot_report_own_content} ->
        {:noreply,
         socket
         |> assign(:report_modal, nil)
         |> put_flash(:error, "自分のコンテンツは報告できません")}

      {:error, :target_not_found} ->
        {:noreply,
         socket
         |> assign(:report_modal, nil)
         |> put_flash(:error, "報告対象が見つかりませんでした")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(:report_modal, nil)
         |> put_flash(:error, "報告に失敗しました。もう一度お試しください。")}
    end
  end
end
```

## live/root.html.heex

対応: 第6〜8章。正本: `live/root.html.heex`

```heex
<!DOCTYPE html>
<html lang="ja">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="csrf-token" content={get_csrf_token()} />
    <.live_title suffix=" · reddit_clone">
      <%= assigns[:page_title] || "reddit_clone" %>
    </.live_title>
    <link phx-track-static rel="stylesheet" href={~p"/assets/app.css"} />
    <script defer phx-track-static type="text/javascript" src={~p"/assets/app.js"}>
    </script>
  </head>

  <body class="bg-gray-100 min-h-screen">

    <%!-- ナビゲーションバー --%>
    <nav class="bg-white border-b border-gray-200 sticky top-0 z-30">
      <div class="max-w-5xl mx-auto px-4 h-12 flex items-center gap-4">

        <%!-- ロゴ --%>
        <a href="/" class="flex items-center gap-1 shrink-0">
          <span class="text-orange-500 text-xl font-black">🔴</span>
          <span class="font-bold text-gray-800 hidden sm:block">reddit_clone</span>
        </a>

        <%!-- 検索フォーム --%>
        <form action="/search" method="get" class="flex-1 max-w-xl">
          <div class="relative">
            <input
              type="text"
              name="q"
              value={assigns[:query] || ""}
              placeholder="検索..."
              class="w-full border border-gray-300 rounded-full px-4 py-1.5 text-sm bg-gray-50 focus:outline-none focus:border-blue-400 focus:bg-white"
            />
            <button
              type="submit"
              class="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
            >
              🔍
            </button>
          </div>
        </form>

        <%!-- 右側: 認証ボタン --%>
        <div class="flex items-center gap-2 shrink-0">
          <%= if @current_user do %>
            <%!-- ログイン済み --%>
            <a
              href={"/u/#{@current_user.username}"}
              class="text-sm text-gray-700 hover:text-blue-500 font-medium hidden sm:block"
            >
              u/<%= @current_user.username %>
            </a>
            <a
              href="/subreddits/new"
              class="text-sm text-gray-500 hover:text-gray-700 px-2 py-1 hidden sm:block"
            >
              ＋ 作成
            </a>
            <a
              href="/logout"
              data-method="delete"
              class="text-sm border border-gray-300 rounded-full px-3 py-1 hover:bg-gray-50"
            >
              ログアウト
            </a>
          <% else %>
            <%!-- 未ログイン --%>
            <a
              href="/login"
              class="text-sm border border-blue-500 text-blue-500 rounded-full px-3 py-1 hover:bg-blue-50"
            >
              ログイン
            </a>
            <a
              href="/register"
              class="text-sm bg-blue-500 text-white rounded-full px-3 py-1 hover:bg-blue-600"
            >
              登録
            </a>
          <% end %>
        </div>

      </div>
    </nav>

    <%!-- メインコンテンツ --%>
    <main>
      <%= @inner_content %>
    </main>

  </body>
</html>
```

## live/search_live.ex（RedditCloneWeb.SearchLive）

対応: 第6〜8章。正本: `live/search_live.ex`

```elixir
defmodule RedditCloneWeb.SearchLive do
  use RedditCloneWeb, :live_view

  import RedditCloneWeb.Components.PostCard
  import RedditCloneWeb.Components.ReportModal

  alias RedditClone.Posts
  alias RedditClone.Communities
  alias RedditClone.Reports

  on_mount {RedditCloneWeb.UserAuth, :fetch_current_user}

  # ----------------------------------------------------------------
  # mount
  # ----------------------------------------------------------------

  @impl true
  def mount(%{"q" => query}, _session, socket) when query != "" do
    posts      = Posts.search_posts(query)
    subreddits = Communities.search_subreddits(query)

    {:ok,
     socket
     |> assign(:page_title, "「#{query}」の検索結果")
     |> assign(:query, query)
     |> assign(:posts, posts)
     |> assign(:subreddits, subreddits)
     |> assign(:report_modal, nil)}
  end

  def mount(_params, _session, socket) do
    # クエリなしでアクセスした場合は空状態
    {:ok,
     socket
     |> assign(:page_title, "検索")
     |> assign(:query, "")
     |> assign(:posts, [])
     |> assign(:subreddits, [])
     |> assign(:report_modal, nil)}
  end

  # ----------------------------------------------------------------
  # イベント処理
  # ----------------------------------------------------------------

  @impl true
  def handle_event("vote", %{"id" => post_id, "value" => value}, socket) do
    case socket.assigns.current_user do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "投票するにはログインが必要です")
         |> redirect(to: "/login")}

      user ->
        value = String.to_integer(value)

        case Posts.vote_post(user.id, post_id, value) do
          {:ok, updated_post} ->
            posts =
              Enum.map(socket.assigns.posts, fn post ->
                if post.id == updated_post.id, do: updated_post, else: post
              end)

            {:noreply, assign(socket, :posts, posts)}

          {:error, :cannot_vote_own_post} ->
            {:noreply, put_flash(socket, :error, "自分の投稿には投票できません")}
        end
    end
  end

  # ----------------------------------------------------------------
  # レンダリング
  # ----------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto px-4 py-6">

      <%!-- 検索フォーム --%>
      <form action="/search" method="get" class="mb-6">
        <div class="flex gap-2">
          <input
            type="text"
            name="q"
            value={@query}
            placeholder="キーワードを入力..."
            class="flex-1 border border-gray-300 rounded px-4 py-2 text-sm focus:outline-none focus:border-blue-400"
            autofocus
          />
          <button
            type="submit"
            class="px-4 py-2 bg-blue-500 text-white text-sm rounded hover:bg-blue-600"
          >
            検索
          </button>
        </div>
      </form>

      <%= if @query == "" do %>
        <p class="text-gray-400 text-center py-12">
          キーワードを入力して検索してください
        </p>
      <% else %>
        <h1 class="text-lg font-bold mb-4">
          「<%= @query %>」の検索結果
        </h1>

        <div class="flex gap-4">

          <%!-- 左カラム: 投稿の検索結果 --%>
          <div class="flex-1">
            <h2 class="text-sm font-bold text-gray-500 uppercase mb-3">
              投稿 <%= if @posts != [], do: "(#{length(@posts)}件)" %>
            </h2>

            <%= if @posts == [] do %>
              <div class="bg-white border border-gray-200 rounded p-6 text-center">
                <p class="text-gray-400 text-sm">投稿が見つかりませんでした</p>
              </div>
            <% else %>
              <%= for post <- @posts do %>
                <.post_card
                  post={post}
                  show_subreddit={true}
                  current_user={@current_user}
                />
              <% end %>
            <% end %>
          </div>

          <%!-- 右カラム: Subredditの検索結果 --%>
          <div class="w-64 shrink-0">
            <h2 class="text-sm font-bold text-gray-500 uppercase mb-3">
              コミュニティ <%= if @subreddits != [], do: "(#{length(@subreddits)}件)" %>
            </h2>

            <%= if @subreddits == [] do %>
              <div class="bg-white border border-gray-200 rounded p-4 text-center">
                <p class="text-gray-400 text-sm">見つかりませんでした</p>
              </div>
            <% else %>
              <%= for subreddit <- @subreddits do %>
                <div class="bg-white border border-gray-200 rounded p-3 mb-2 hover:border-gray-400">
                  <.link navigate={~p"/r/#{subreddit.name}"} class="block">
                    <p class="font-medium text-sm">r/<%= subreddit.name %></p>
                    <%= if subreddit.description do %>
                      <p class="text-xs text-gray-400 mt-1 truncate">
                        <%= subreddit.description %>
                      </p>
                    <% end %>
                  </.link>
                </div>
              <% end %>
            <% end %>

          </div>
        </div>
      <% end %>

    </div>

    <%!-- 報告モーダル --%>
    <.report_modal report_modal={@report_modal} />
    """
  end

  # 報告モーダルを開く
  def handle_event("open_report_modal", %{"type" => type, "id" => id}, socket) do
    case socket.assigns.current_user do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "報告するにはログインが必要です")
         |> redirect(to: "/login")}

      _ ->
        {:noreply, assign(socket, :report_modal, %{target_type: type, target_id: id})}
    end
  end

  # 報告モーダルを閉じる
  def handle_event("close_report_modal", _params, socket) do
    {:noreply, assign(socket, :report_modal, nil)}
  end

  # 報告を送信する
  def handle_event("submit_report", params, socket) do
    attrs = %{
      "reporter_id" => socket.assigns.current_user.id,
      "target_type" => params["target_type"],
      "target_id"   => params["target_id"],
      "reason"      => params["reason"]
    }

    case Reports.create_report(attrs) do
      {:ok, _report} ->
        {:noreply,
         socket
         |> assign(:report_modal, nil)
         |> put_flash(:info, "報告しました。ご協力ありがとうございます。")}

      {:error, :cannot_report_own_content} ->
        {:noreply,
         socket
         |> assign(:report_modal, nil)
         |> put_flash(:error, "自分のコンテンツは報告できません")}

      {:error, :target_not_found} ->
        {:noreply,
         socket
         |> assign(:report_modal, nil)
         |> put_flash(:error, "報告対象が見つかりませんでした")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(:report_modal, nil)
         |> put_flash(:error, "報告に失敗しました。もう一度お試しください。")}
    end
  end
end
```

## live/subreddit_live.ex（RedditCloneWeb.SubredditLive）

対応: 第6〜8章。正本: `live/subreddit_live.ex`

```elixir
defmodule RedditCloneWeb.SubredditLive do
  use RedditCloneWeb, :live_view

  import RedditCloneWeb.Components.PostCard
  import RedditCloneWeb.Components.ReportModal

  alias RedditClone.Communities
  alias RedditClone.Posts
  alias RedditClone.Reports

  on_mount {RedditCloneWeb.UserAuth, :fetch_current_user}

  # ----------------------------------------------------------------
  # mount: 初回データ取得
  # ----------------------------------------------------------------

  @impl true
  def mount(%{"name" => name}, _session, socket) do
    case Communities.get_subreddit_by_name(name) do
      nil ->
        # Subredditが存在しない場合
        {:ok,
         socket
         |> put_flash(:error, "r/#{name} は存在しません")
         |> redirect(to: "/")}

      subreddit ->
        posts   = Posts.list_posts(subreddit.id, "hot", 1)
        joined? = joined?(socket.assigns.current_user, subreddit.id)

        {:ok,
         socket
         |> assign(:page_title, "r/#{subreddit.name}")
         |> assign(:subreddit, subreddit)
         |> assign(:posts, posts)
         |> assign(:sort, "hot")
         |> assign(:page, 1)
         |> assign(:has_more?, length(posts) == 25)
         |> assign(:report_modal, nil)
         |> assign(:joined?, joined?)}
    end
  end

  # ----------------------------------------------------------------
  # イベント処理
  # ----------------------------------------------------------------

  @impl true
  def handle_event("sort", %{"value" => sort}, socket) do
    # ソート切り替え時はページを1に戻す
    posts = Posts.list_posts(socket.assigns.subreddit.id, sort, 1)

    {:noreply,
     socket
     |> assign(:sort, sort)
     |> assign(:page, 1)
     |> assign(:has_more?, length(posts) == 25)
     |> assign(:posts, posts)}
  end

  def handle_event("join", _params, socket) do
    case socket.assigns.current_user do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "参加するにはログインが必要です")
         |> redirect(to: "/login")}

      user ->
        case Communities.join_subreddit(user.id, socket.assigns.subreddit.id) do
          {:ok, _member} ->
            {:noreply, assign(socket, :joined?, true)}

          {:error, _changeset} ->
            # 登録できなかった場合（すでに参加済みなど）は、実際の参加状態に合わせる
            {:noreply, assign(socket, :joined?, joined?(user, socket.assigns.subreddit.id))}
        end
    end
  end

  def handle_event("leave", _params, socket) do
    case Communities.leave_subreddit(
           socket.assigns.current_user.id,
           socket.assigns.subreddit.id
         ) do
      {:ok, _} ->
        {:noreply, assign(socket, :joined?, false)}

      {:error, :owner_cannot_leave} ->
        {:noreply, put_flash(socket, :error, "作成者はコミュニティを脱退できません")}
    end
  end

  def handle_event("load_more", _params, socket) do
    next_page  = socket.assigns.page + 1
    new_posts  = Posts.list_posts(socket.assigns.subreddit.id, socket.assigns.sort, next_page)

    {:noreply,
     socket
     |> assign(:page, next_page)
     |> assign(:has_more?, length(new_posts) == 25)
     |> assign(:posts, socket.assigns.posts ++ new_posts)}  # 既存に追記
  end

  def handle_event("vote", %{"id" => post_id, "value" => value}, socket) do
    case socket.assigns.current_user do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "投票するにはログインが必要です")
         |> redirect(to: "/login")}

      user ->
        value = String.to_integer(value)

        case Posts.vote_post(user.id, post_id, value) do
          {:ok, updated_post} ->
            # 該当の投稿だけスコアを更新する
            posts =
              Enum.map(socket.assigns.posts, fn post ->
                if post.id == updated_post.id, do: updated_post, else: post
              end)

            {:noreply, assign(socket, :posts, posts)}

          {:error, :cannot_vote_own_post} ->
            {:noreply, put_flash(socket, :error, "自分の投稿には投票できません")}
        end
    end
  end

  # ----------------------------------------------------------------
  # レンダリング
  # ----------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto px-4 py-4 flex gap-4">

      <%!-- メインカラム --%>
      <div class="flex-1">

        <%!-- ソートタブ --%>
        <div class="bg-white border border-gray-200 rounded p-2 mb-4 flex gap-2">
          <button
            phx-click="sort"
            phx-value-value="hot"
            class={tab_class(@sort, "hot")}
          >
            🔥 Hot
          </button>
          <button
            phx-click="sort"
            phx-value-value="new"
            class={tab_class(@sort, "new")}
          >
            ✨ New
          </button>
        </div>

        <%!-- 投稿一覧 --%>
        <%= if @posts == [] do %>
          <p class="text-gray-500 text-center py-8">まだ投稿がありません</p>
        <% else %>
          <%= for post <- @posts do %>
            <.post_card
              post={post}
              show_subreddit={false}
              current_user={@current_user}
            />
          <% end %>

          <%!-- もっと見るボタン --%>
          <%= if @has_more? do %>
            <div class="text-center py-4">
              <button
                phx-click="load_more"
                class="px-6 py-2 border border-gray-300 rounded text-sm text-gray-600 hover:bg-gray-50"
              >
                もっと見る
              </button>
            </div>
          <% end %>
        <% end %>

      </div>

      <%!-- サイドバー --%>
      <div class="w-72 shrink-0">
        <div class="bg-white border border-gray-200 rounded p-4">

          <h2 class="font-bold text-lg mb-2">r/<%= @subreddit.name %></h2>

          <%= if @subreddit.description do %>
            <p class="text-sm text-gray-600 mb-4"><%= @subreddit.description %></p>
          <% end %>

          <%!-- Join / Leave ボタン --%>
          <%= if @current_user do %>
            <%= if @joined? do %>
              <button
                phx-click="leave"
                class="w-full border border-blue-500 text-blue-500 rounded-full py-1 text-sm hover:bg-blue-50"
              >
                参加中
              </button>
            <% else %>
              <button
                phx-click="join"
                class="w-full bg-blue-500 text-white rounded-full py-1 text-sm hover:bg-blue-600"
              >
                参加する
              </button>
            <% end %>
          <% end %>

          <%!-- 投稿するボタン --%>
          <%= if @current_user do %>
            <.link
              navigate={~p"/r/#{@subreddit.name}/submit"}
              class="block w-full mt-2 border border-gray-300 text-center rounded-full py-1 text-sm hover:bg-gray-50"
            >
              投稿する
            </.link>
          <% end %>

        </div>
      </div>

    </div>

    <%!-- 報告モーダル --%>
    <.report_modal report_modal={@report_modal} />
    """
  end

  # ----------------------------------------------------------------
  # ヘルパー
  # ----------------------------------------------------------------

  defp joined?(nil, _subreddit_id), do: false
  defp joined?(user, subreddit_id),  do: Communities.member?(user.id, subreddit_id)

  defp tab_class(current, tab) when current == tab do
    "px-4 py-1 rounded bg-gray-200 font-bold text-sm"
  end
  defp tab_class(_, _) do
    "px-4 py-1 rounded hover:bg-gray-100 text-sm text-gray-600"
  end

  # 報告モーダルを開く
  def handle_event("open_report_modal", %{"type" => type, "id" => id}, socket) do
    case socket.assigns.current_user do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "報告するにはログインが必要です")
         |> redirect(to: "/login")}

      _ ->
        {:noreply, assign(socket, :report_modal, %{target_type: type, target_id: id})}
    end
  end

  # 報告モーダルを閉じる
  def handle_event("close_report_modal", _params, socket) do
    {:noreply, assign(socket, :report_modal, nil)}
  end

  # 報告を送信する
  def handle_event("submit_report", params, socket) do
    attrs = %{
      "reporter_id"  => socket.assigns.current_user.id,
      "target_type"  => params["target_type"],
      "target_id"    => params["target_id"],
      "reason"       => params["reason"]
    }

    case Reports.create_report(attrs) do
      {:ok, _report} ->
        {:noreply,
         socket
         |> assign(:report_modal, nil)
         |> put_flash(:info, "報告しました。ご協力ありがとうございます。")}

      {:error, :cannot_report_own_content} ->
        {:noreply,
         socket
         |> assign(:report_modal, nil)
         |> put_flash(:error, "自分のコンテンツは報告できません")}

      {:error, :target_not_found} ->
        {:noreply,
         socket
         |> assign(:report_modal, nil)
         |> put_flash(:error, "報告対象が見つかりませんでした")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(:report_modal, nil)
         |> put_flash(:error, "報告に失敗しました。もう一度お試しください。")}
    end
  end
end
```
