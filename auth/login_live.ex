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
