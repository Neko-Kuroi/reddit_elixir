# 第5章　認証（前編）

---

## 5-1　Phoenix の認証の仕組み

認証とは「このユーザーは誰か」をアプリが把握し続ける仕組みです。

HTTP はステートレスなプロトコルです。ページを移動するたびにサーバーはリクエストを送ってきた人が誰かを知りません。そこで**セッション**を使います。

```
ログイン時
  ① フォームで email + password を送信
  ② サーバーでパスワードを照合
  ③ 正しければ セッションに user_id を保存
       └─ サーバー側のセッションストアに保存
       └─ ブラウザには暗号化された Cookie を渡す

その後のリクエストごとに
  ④ ブラウザが Cookie を自動的に送ってくる
  ⑤ Cookie からセッション ID を取り出す
  ⑥ セッションストアから user_id を取り出す
  ⑦ DB からユーザーを取得して assigns に入れる
```

セッションに保存するのは `user_id` だけです。ユーザー名やメールアドレスは保存しません。改ざんのリスクを最小限にするためです。

---

## 5-2　LiveView とセッションの制約

Phoenix LiveView には重要な制約があります。

**LiveView はセッションに直接書き込めません。**

通常の HTTP リクエストでは Plug を使ってセッションを操作できます。しかし LiveView は WebSocket 接続で動作するため、セッションへの書き込みができません。

この制約を回避するために **Phoenix.Token** を使います。

```
LoginLive（LiveView）
  ① ログイン成功
  ② user_id を Phoenix.Token で署名してトークンを生成
  ③ /session?token=xxx にリダイレクト

SessionController（通常のコントローラー）
  ④ token を受け取る
  ⑤ Phoenix.Token で署名を検証
  ⑥ user_id を取り出してセッションに保存
  ⑦ ホームページへリダイレクト
```

なぜ `user_id` をそのまま URL に入れないのかというと、ブラウザの履歴やサーバーのログに残るためです。Token で署名することで改ざんを防ぎ、有効期限（60秒）で使い捨てにできます。

---

## 5-3　UserAuth モジュール

```elixir
# lib/reddit_clone_web/user_auth.ex
defmodule RedditCloneWeb.UserAuth do
  use RedditCloneWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias RedditClone.Accounts

  @session_key "user_id"

  # ----------------------------------------------------------------
  # Plugs（通常の HTTP リクエスト用）
  # ----------------------------------------------------------------

  # セッションから user_id を取り出してユーザーを取得する
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

  # 未ログインのユーザーをログインページへ飛ばす
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

  # ログイン済みのユーザーをホームへ飛ばす（登録・ログインページ用）
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

  def log_in_user(conn, user, params \\ %{}) do
    conn
    |> renew_session()
    |> put_session(@session_key, user.id)
    |> redirect(to: params["return_to"] || ~p"/")
  end

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
  # LiveView 用ヘルパー（on_mount）
  # ----------------------------------------------------------------

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

  defp mount_current_user(session, socket) do
    current_user =
      case Map.get(session, @session_key) do
        nil     -> nil
        user_id -> Accounts.get_user!(user_id)
      end

    Phoenix.Component.assign(socket, :current_user, current_user)
  end
end
```

**解説**

`fetch_current_user/2` は Plug です。全リクエストに適用して `conn.assigns.current_user` にユーザーをセットします。未ログインのときは `nil` になります。

`require_auth/2` はログインが必要なページを保護する Plug です。`halt()` を呼ぶことで後続の Plug 処理を止めます。

`renew_session/1` はセッション固定攻撃を防ぐために重要です。

```elixir
conn
|> configure_session(renew: true)  # セッション ID を新しく発行する
|> clear_session()                 # 古いセッションの内容を削除する
```

ログイン前のセッション ID をそのまま使うと、攻撃者が事前に仕込んだセッション ID でなりすますことができます。ログイン・ログアウト時にセッション ID を再生成することでこれを防ぎます。

`on_mount/4` は LiveView 専用の認証ヘルパーです。LiveView のマウント時に呼ばれ、セッションからユーザーを取得してソケットにセットします。`{:cont, socket}` で処理を続行、`{:halt, socket}` でリダイレクトします。

---

## 5-4　SessionController

```elixir
# lib/reddit_clone_web/controllers/session_controller.ex
defmodule RedditCloneWeb.SessionController do
  use RedditCloneWeb, :controller

  alias RedditClone.Accounts
  alias RedditCloneWeb.UserAuth

  @max_age 60  # トークンの有効期限（秒）

  def create(conn, %{"token" => token}) do
    case Phoenix.Token.verify(
           RedditCloneWeb.Endpoint,
           "user_auth",
           token,
           max_age: @max_age
         ) do
      {:ok, user_id} ->
        user = Accounts.get_user!(user_id)
        UserAuth.log_in_user(conn, user)

      {:error, _reason} ->
        conn
        |> put_flash(:error, "セッションが無効です。もう一度ログインしてください")
        |> redirect(to: ~p"/login")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "ログアウトしました")
    |> UserAuth.log_out_user()
  end
end
```

**解説**

`Phoenix.Token.verify/4` でトークンを検証します。

```elixir
Phoenix.Token.verify(
  RedditCloneWeb.Endpoint,  # 署名に使ったエンドポイント（sign と同じ）
  "user_auth",              # salt（sign と同じ文字列）
  token,                    # 受け取ったトークン
  max_age: @max_age         # 有効期限（60秒以内のトークンのみ受け付ける）
)
```

`sign` と `verify` の両方で同じ `"user_auth"` という salt を使います。これが違うと検証が失敗します。`max_age: 60` で60秒以上前に発行されたトークンを拒否します。

---

後編では RegisterLive・LoginLive・Router を実装します。
