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
