# 第5章　認証（前編）

---

### この章で学ぶこと

- 作るもの: 認証の仕組み一式。前編では UserAuth（Plug と on_mount）と SessionController、後編では RegisterLive・LoginLive と Router を扱います
- 学ぶ考え方: セッションと Cookie の仕組み、Plug とパイプライン、Phoenix.Token による署名、LiveView がセッションに直接書けない制約とその回避法

### 前提

- 第4章が済んでいること（特に `Accounts.login_user/2` と `Accounts.register_user/1` が書けていること）
- 第3章の User スキーマ（パスワードのハッシュ化）が済んでいること

### 全体の中での位置

この章は Web 層の入口を作る章です。画面そのものではなく、「誰がアクセスしているか」を全画面の手前で判定する仕組みを用意します。ここで作る UserAuth と Router の保護があって初めて、第6章の画面を「ログインが必要な画面」と「誰でも見られる画面」に分けて作れます。

> この章のコードについて: 実ファイルのうち UserAuth と SessionController の各関数には `@doc`（関数の説明文）が付いています。本文では関数の本体に集中するため `@doc` は省略しています。`@doc` を含む全文は、全コード付録3（appendix_code_03_web.md）に収録しています。

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

**読み解き**

言葉を2つ押さえます。**ステートレス**とは「サーバーが、前のリクエストのことを覚えていない」という性質です。HTTP のリクエストは1回ごとに独立しているため、「さっきログインした人」という情報をサーバー側でつなぐ仕掛けが要ります。それがセッションです。

**Cookie** は、ブラウザ側に保存される小さなデータで、リクエストのたびに自動でサーバーへ送り返されます。Phoenix のセッションは、セッションの中身そのもの（またはその鍵）を Cookie に載せてブラウザに持たせ、リクエストごとに受け取って読み解く方式です。Cookie の中身は署名されているため、ブラウザ側で書き換えると検出できます（署名については次の節で Token とあわせて説明します）。

「保存するのは `user_id` だけ」という決まりも大切です。セッションに入れる情報が少ないほど、漏れたとき・書き換えられたときの被害が小さくなります。ユーザー名などが必要なら、その都度 `user_id` から DB で引き直します。

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

**読み解き**

Phoenix.Token の仕組みをほぐします。`Phoenix.Token.sign` は、「データ（ここでは `user_id`）」と「サーバーだけが知っている秘密」と「salt（用途を区別するための文字列）」から、署名付きの文字列（トークン）を作ります。

- 署名は「改ざんの検出」のためのものです。トークンの中身は暗号化されているわけではなく読むことはできますが、書き換えると署名が合わなくなり、`Phoenix.Token.verify` が失敗します
- 検証は、受け取ったトークンに対して同じ秘密と salt で署名を確かめることで行います。だから `sign` と `verify` で salt が食い違うと、正しいトークンでも検証に失敗します
- `max_age` は「発行から何秒まで受け付けるか」です。トークンには発行時刻の情報が含まれていて、検証のときに経過時間を確認できます

この章では salt に `"user_auth"` を使い、有効期限は60秒です。ログイン直後に1回だけ使う「受け渡し専用の切符」なので、短くて十分です。

---

## 5-3　UserAuth モジュール

```elixir
# lib/reddit_clone_web/user_auth.ex
defmodule RedditCloneWeb.UserAuth do
  use RedditCloneWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias RedditClone.Accounts

  # セッションのキー名
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

**読み解き**

まず **Plug** という考え方を押さえます。Plug とは「接続情報（`conn`）を受け取り、加工して `conn` を返す関数（またはモジュール）」の約束事です。リクエストは、複数の Plug を順番に通ることで処理されていきます。この並びのことをパイプラインと呼びます（チェンジセットのパイプと発想は同じで、「受け取って、加工して、次へ渡す」の繰り返しです）。途中の Plug が `halt()` を呼ぶと、そこで処理が打ち切られ、後ろの Plug や本来の画面には進みません。

`fetch_current_user/2` は Plug です。全リクエストに適用して `conn.assigns.current_user` にユーザーをセットします。未ログインのときは `nil` になります。`assigns` は「そのリクエストの間だけ使う、値の置き場所」です。

`require_auth/2` はログインが必要なページを保護する Plug です。`halt()` を呼ぶことで後続の Plug 処理を止めます。

`renew_session/1` はセッション固定攻撃を防ぐために重要です。

```elixir
conn
|> configure_session(renew: true)  # セッション ID を新しく発行する
|> clear_session()                 # 古いセッションの内容を削除する
```

ログイン前のセッション ID をそのまま使うと、攻撃者が事前に仕込んだセッション ID でなりすますことができます。ログイン・ログアウト時にセッション ID を再生成することでこれを防ぎます。

`on_mount/4` は LiveView 専用の認証ヘルパーです。LiveView のマウント時に呼ばれ、セッションからユーザーを取得してソケットにセットします。`{:cont, socket}` で処理を続行、`{:halt, socket}` でリダイレクトします。

`on_mount` には3つのバリエーションがあり、関数の複数節（第4章）で書き分けられています。違いは「ログイン状態によって画面を止めるかどうか」です。

| バリエーション | 未ログインのとき | ログイン済みのとき | 用途 |
|---|---|---|---|
| `:fetch_current_user` | そのまま通す（`current_user` は `nil`） | そのまま通す | 誰でも見られるが、ログイン状態で表示を変えたい画面 |
| `:require_auth` | ログイン画面へ飛ばして止める | そのまま通す | ログインが必要な画面 |
| `:redirect_if_authenticated` | そのまま通す | ホームへ飛ばして止める | 登録・ログイン画面 |

3つとも、土台として `mount_current_user/2` がセッションからユーザーを取得する部分は共通です。「取得は共通、判定だけが違う」という分け方になっています。Plug 版（`fetch_current_user/2` など）と役割がそっくりなのは偶然ではなく、「通常のリクエスト用」と「LiveView 用」に同じ考え方を2通り用意しているためです。

---

## 5-4　SessionController

```elixir
# lib/reddit_clone_web/controllers/session_controller.ex
defmodule RedditCloneWeb.SessionController do
  use RedditCloneWeb, :controller

  alias RedditClone.Accounts
  alias RedditCloneWeb.UserAuth

  # トークンの有効期限（秒）
  # LoginLive で生成してからこのコントローラーに届くまでの時間
  @max_age 60

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

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "ログアウトしました")
    |> UserAuth.log_out_user()
  end
end
```

**読み解き**

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

なお `create(conn, %{"token" => token})` という引数もパターンマッチです。受け取ったパラメータの中から `"token"` の値だけを取り出して変数に入れています。ここが通常のコントローラーである点が重要で、セッションへの書き込みはこの層でなら行えます。LiveView（5-2 の制約）とコントローラーの役割分担が、このファイルに表れています。

---

後編では RegisterLive・LoginLive・Router を実装します。
