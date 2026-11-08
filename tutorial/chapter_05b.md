# 第5章　認証（後編）

---

## 5-5　RegisterLive

```elixir
# lib/reddit_clone_web/live/register_live.ex
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
    changeset =
      %User{}
      |> User.registration_changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("register", %{"user" => params}, socket) do
    case Accounts.register_user(params) do
      {:ok, user} ->
        token = Phoenix.Token.sign(
          RedditCloneWeb.Endpoint,
          "user_auth",
          user.id
        )

        {:noreply,
         socket
         |> put_flash(:info, "登録が完了しました！")
         |> redirect(to: "/session?token=#{token}")}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-md mx-auto mt-16 p-6">
      <h1 class="text-2xl font-bold mb-6">アカウントを作成</h1>

      <.form for={@form} phx-change="validate" phx-submit="register">
        <div class="mb-4">
          <.input field={@form[:username]} label="ユーザー名" placeholder="例: alice" />
        </div>
        <div class="mb-4">
          <.input field={@form[:email]} type="email" label="メールアドレス" />
        </div>
        <div class="mb-6">
          <.input field={@form[:password]} type="password" label="パスワード（8文字以上）" />
        </div>
        <.button type="submit" class="w-full">登録する</.button>
      </.form>

      <p class="mt-4 text-center text-sm">
        すでにアカウントをお持ちですか？
        <.link navigate="/login" class="text-blue-500 hover:underline">ログイン</.link>
      </p>
    </div>
    """
  end

  defp assign_form(socket, changeset) do
    assign(socket, :form, to_form(changeset, as: "user"))
  end
end
```

**解説**

`on_mount {RedditCloneWeb.UserAuth, :redirect_if_authenticated}` はすでにログイン済みのユーザーをホームページへ飛ばします。ログイン済みのユーザーが登録ページにアクセスしても意味がないためです。

`handle_event("validate", ...)` は入力中にリアルタイムでバリデーションを実行します。`phx-change="validate"` と対応しています。

```elixir
changeset
|> Map.put(:action, :validate)
```

`:action` を `:validate` にセットすることで、Ecto がエラーメッセージを表示するモードになります。これがないと入力中にエラーが表示されません。

登録成功後は `Phoenix.Token.sign` でトークンを生成し、`SessionController` 経由で自動ログインします。

---

## 5-6　LoginLive

```elixir
# lib/reddit_clone_web/live/login_live.ex
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
        token = Phoenix.Token.sign(
          RedditCloneWeb.Endpoint,
          "user_auth",
          user.id
        )

        {:noreply,
         socket
         |> put_flash(:info, "ログインしました")
         |> redirect(to: "/session?token=#{token}")}

      {:error, :invalid_credentials} ->
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
        <div class="mb-4">
          <.input field={@form[:email]} type="email" label="メールアドレス" />
        </div>
        <div class="mb-6">
          <.input field={@form[:password]} type="password" label="パスワード" />
        </div>
        <.button type="submit" class="w-full">ログイン</.button>
      </.form>

      <p class="mt-4 text-center text-sm">
        アカウントをお持ちでないですか？
        <.link navigate="/register" class="text-blue-500 hover:underline">新規登録</.link>
      </p>
    </div>
    """
  end
end
```

**解説**

ログイン失敗時のエラーメッセージは「メールアドレスまたはパスワードが違います」のみです。「メールが存在しません」「パスワードが違います」と分けて伝えると、攻撃者がどのメールアドレスが登録済みかを判断できてしまいます。

失敗時に `email` の値をフォームに残すのはユーザーへの配慮です。メールアドレスは再入力が面倒なためです。パスワードは残しません。

---

## 5-7　Router

```elixir
# lib/reddit_clone_web/router.ex
defmodule RedditCloneWeb.Router do
  use RedditCloneWeb, :router

  import RedditCloneWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {RedditCloneWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user          # 全リクエストでユーザーを取得
  end

  # セッション操作（コントローラー経由）
  scope "/", RedditCloneWeb do
    pipe_through [:browser]

    get    "/session", SessionController, :create
    delete "/logout",  SessionController, :delete
  end

  # 未ログインでも見られるが、ログイン済みはリダイレクト
  scope "/", RedditCloneWeb do
    pipe_through [:browser, :redirect_if_authenticated]

    live "/register", RegisterLive
    live "/login",    LoginLive
  end

  # 未ログインでも見られる公開ページ
  scope "/", RedditCloneWeb do
    pipe_through [:browser]

    live "/r/:name",          SubredditLive
    live "/r/:name/:post_id", PostLive
    live "/u/:username",      ProfileLive
    live "/search",           SearchLive
  end

  # ログインが必要なページ
  scope "/", RedditCloneWeb do
    pipe_through [:browser, :require_auth]

    live "/",               HomeFeedLive
    live "/subreddits/new", NewSubredditLive
    live "/r/:name/submit", NewPostLive
  end
end
```

**解説**

Router はリクエストを受け取り、適切な LiveView やコントローラーに振り分けます。`pipe_through` でどの Plug を通すかを指定します。

`pipeline :browser` に `plug :fetch_current_user` を追加しているのがポイントです。全てのリクエストでユーザーを取得するため、どの画面でも `@current_user` が使えます。

スコープを4つに分けています。

```
① セッション操作   → 認証なし（コントローラー）
② 登録・ログイン   → ログイン済みはホームへリダイレクト
③ 公開ページ       → 誰でも見られる
④ 認証必須ページ   → 未ログインはログインへリダイレクト
```

`/u/:username` はプロフィールページです。誰のプロフィールも見られるように公開スコープに置きます。

`/subreddits/new` や `/r/:name/submit` は投稿・作成画面です。ログインが必要なため認証必須スコープに置きます。

---

## まとめ

この章では以下を完了しました。

```
✅ Phoenix セッションの仕組みを理解した
✅ LiveView がセッションに書けない制約を理解した
✅ Phoenix.Token でセキュアに user_id を渡す方法を学んだ
✅ UserAuth Plug と on_mount を実装した
✅ RegisterLive / LoginLive を実装した
✅ SessionController を実装した
✅ Router でページを保護した
```

**セキュリティの重要なポイント**

- セッションには `user_id` だけを保存する
- ログイン・ログアウト時にセッション ID を再生成する
- `user_id` を URL に直接入れず Phoenix.Token で署名する
- ログイン失敗の理由を分けて伝えない

次の章では、LiveView を使って実際の画面を実装します。コミュニティページ・投稿作成・投稿詳細・ホーム Feed などを順番に作っていきます。
