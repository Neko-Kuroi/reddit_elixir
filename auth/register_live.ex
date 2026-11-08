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
