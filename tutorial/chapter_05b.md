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

**読み解き**

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

**読み解き**

ログイン失敗時のエラーメッセージは「メールアドレスまたはパスワードが違います」のみです。「メールが存在しません」「パスワードが違います」と分けて伝えると、攻撃者がどのメールアドレスが登録済みかを判断できてしまいます。第4章の `login_user/2` が理由を曖昧にした設計と、ここでも一貫させています。

失敗時に `email` の値をフォームに残すのはユーザーへの配慮です。メールアドレスは再入力が面倒なためです。パスワードは残しません。

---

## 5-7　Router

```elixir
# lib/reddit_clone_web/router.ex
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

**読み解き**

Router はリクエストを受け取り、適切な LiveView やコントローラーに振り分けます。`pipe_through` でどの Plug を通すかを指定します。

用語を整理します。**pipeline** は「このルートの前に通す Plug の並び」に名前を付けたものです。**scope** は「URL のまとまり」のことで、まとまりごとに `pipe_through` で適用する pipeline を指定します。つまり Router は「どの URL に、どの前処理をして、どの画面へ渡すか」の表です。

`pipeline :api` は JSON で応答する API 用の並びですが、このアプリには API のルートが無いため、実際には使われません。プロジェクト生成時の雛形として残っているものとして、そのままにしてあります。

`pipeline :browser` に `plug :fetch_current_user` を追加しているのがポイントです。全てのリクエストでユーザーを取得するため、どの画面でも `@current_user` が使えます。

なお、認証の判定は Router だけに任せているわけではありません。RegisterLive と LoginLive の冒頭で見た `on_mount` の宣言のように、LiveView 側でもログイン状態を確認しています。「入口（Router）」と「画面自身（on_mount）」の二段構えです。Phoenix には `live_session` という仕組みで on_mount をルート側にまとめる書き方もありますが、このコードでは各 LiveView に `on_mount` を直接書く方式を採っています。

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

## 動作確認（この章の仕上げ）

前提: 第1〜4章が済み、`mix phx.server` でサーバーが起動できること（組み立てたプロジェクトの環境で確認します）。

- [ ] 未ログインの状態で `/register` を開き、ユーザー名・メールアドレス・パスワード（8文字以上）で登録すると、「登録が完了しました！」と表示され、そのままログインした状態でホームへ進む（Token 経由の自動ログインが動いている）
- [ ] 登録の入力中、パスワードを7文字にすると送信前にエラーが表示される（リアルタイム検証が動いている）。ユーザー名を2文字にした場合も同様
- [ ] ログアウトするとログイン画面へ戻り、その状態で `/`（ホーム Feed）を開くと、ログイン画面へ飛ばされる
- [ ] `/login` で間違ったパスワードを入力すると「メールアドレスまたはパスワードが違います」とだけ表示され、メールアドレスの入力は残る
- [ ] 正しい情報でログインするとホームへ進む。ログインした状態で `/login` や `/register` を開くと、ホームへ戻される
- [ ] 未ログインでも `/r/:name` のコミュニティページや `/search` の検索ページは開ける（公開ページの確認）

---

## よくあるエラーと対処

| 症状 | 原因 | 直し方 |
|------|------|--------|
| ログインしたのに「セッションが無効です」と言われて戻される | `sign` と `verify` で salt が食い違っている、または発行から60秒を超えている | 両側の salt（`"user_auth"`）が同じか確認する。再現が遅い場合は、途中で止まっていないか手順を見直す |
| 登録・ログインの直後に毎回はじかれる | Token の受け渡し先（`/session`）が Router に無い、または SessionController に届いていない | Router のセッション操作の scope に `get "/session", SessionController, :create` があるか確認する |
| 画面で `@current_user` が無いと言われる／未ログイン扱いになる | その LiveView に `on_mount` の宣言が無い | 画面の冒頭に、用途に合った `on_mount {RedditCloneWeb.UserAuth, :fetch_current_user}` などを追加する |
| 全画面で `current_user` が取得できない | `pipeline :browser` に `plug :fetch_current_user` が入っていない | Router の `:browser` パイプラインに Plug を追加する |
| セッションキーを変えたらログインできなくなった | 書き込む側と読み出す側でキー名が食い違っている | `@session_key` のように、キー名は1か所の定数で管理し、直接文字列を書かない |

---

## 確認問題

1. LiveView からセッションに直接書き込めないのはなぜですか。その制約を、この章ではどのような流れで回避しましたか。
2. ログイン済みのユーザーが `/register` を開くと何が起きますか。どの仕組みが、どの戻り値でそれを実現していますか。
3. `on_mount(:fetch_current_user, ...)` と `on_mount(:require_auth, ...)` の違いは何ですか。「取得」と「判定」という言葉を使って説明してください。
4. ログイン・ログアウトのときにセッション ID を再生成（`renew_session`）するのはなぜですか。
5. ログイン失敗のメッセージを「メールアドレスまたはパスワードが違います」と1つにまとめているのはなぜですか。第4章のどの設計と対応していますか。

---

## まとめと次章へのつながり

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

次の章では、LiveView を使って実際の画面を実装します。コミュニティページ・投稿作成・投稿詳細・ホーム Feed などを順番に作っていきます。各画面の冒頭では、この章で作った `on_mount` を使ってログイン状態を受け取ります。

---

## 確認問題の答え

1. LiveView は WebSocket で動作し、通常の HTTP レスポンスを持たないためです。回避の流れは「LiveView でログインに成功 → user_id を Phoenix.Token で署名して `/session?token=...` へリダイレクト → SessionController が検証してセッションに保存する」です。
2. ホーム（`/`）へリダイレクトされ、登録画面は表示されません。RegisterLive の `on_mount` に指定した `:redirect_if_authenticated` が、ログイン済みの場合に `{:halt, socket}` を返して処理を止めるためです。
3. どちらもセッションからユーザーを取得する点は共通です。違いは判定の有無で、`:fetch_current_user` は取得だけをして常に `{:cont, socket}` で通し、`:require_auth` は取得した結果が無ければ `{:halt, socket}` で止めてログイン画面へ飛ばします。
4. ログイン前のセッション ID を使い続けると、攻撃者が事前に仕込んだセッション ID でなりすませる（セッション固定攻撃）ためです。ログイン・ログアウトの節目で ID を発行し直し、古いセッションの中身も消します。
5. どちらが間違っているかを教えると、攻撃者が「そのメールアドレスは登録済みか」を判別できてしまうためです。第4章の `Accounts.login_user/2` が、失敗理由を `{:error, :invalid_credentials}` の1種類に曖昧化した設計と対応しています。
