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
