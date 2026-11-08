defmodule RedditClone.Accounts do
  @moduledoc """
  アカウント関連のビジネスロジック。
  ユーザー登録・ログイン・取得・Karma更新を担当する。
  """

  import Ecto.Query
  alias RedditClone.Repo
  alias RedditClone.Accounts.User

  # ----------------------------------------------------------------
  # ① ユーザー登録
  # ----------------------------------------------------------------

  @doc """
  新しいユーザーを登録する。

  ## 例
      iex> register_user(%{username: "alice", email: "alice@example.com", password: "password123"})
      {:ok, %User{}}

      iex> register_user(%{username: "", email: "", password: ""})
      {:error, %Ecto.Changeset{}}
  """
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  登録フォームの初期表示用に空のチェンジセットを返す。
  バリデーションは行わない（まだ何も入力されていないため）。

  ## 例
      iex> change_user_registration(%User{})
      %Ecto.Changeset{}
  """
  def change_user_registration(%User{} = user) do
    User.registration_changeset(user, %{})
  end

  # ----------------------------------------------------------------
  # ② ログイン
  # ----------------------------------------------------------------

  @doc """
  emailとpasswordでログインする。
  失敗理由はあえて曖昧にする（セキュリティ上の理由）。

  ## 例
      iex> login_user("alice@example.com", "password123")
      {:ok, %User{}}

      iex> login_user("alice@example.com", "wrongpassword")
      {:error, :invalid_credentials}
  """
  def login_user(email, password) do
    user = Repo.get_by(User, email: email)
    verify_password(user, password)
  end

  # ユーザーが存在してパスワードが一致する場合のみ成功
  defp verify_password(%User{} = user, password) do
    if Bcrypt.verify_pass(password, user.password_hash) do
      {:ok, user}
    else
      {:error, :invalid_credentials}
    end
  end

  # ユーザーが存在しない場合もタイミング攻撃を防ぐためダミーチェックを行う
  defp verify_password(nil, _password) do
    Bcrypt.no_user_verify()
    {:error, :invalid_credentials}
  end

  # ----------------------------------------------------------------
  # ③ ユーザーを1件取得
  # ----------------------------------------------------------------

  @doc """
  usernameでユーザーを取得する（プロフィールページ用）。

  ## 例
      iex> get_user_by_username("alice")
      %User{}

      iex> get_user_by_username("nobody")
      nil
  """
  def get_user_by_username(username) do
    Repo.get_by(User, username: username)
  end

  @doc """
  idでユーザーを取得する。
  存在しない場合はエラーを返す。
  """
  def get_user!(id), do: Repo.get!(User, id)

  # ----------------------------------------------------------------
  # ④ Karmaの更新
  # ----------------------------------------------------------------

  @doc """
  ユーザーのKarmaを増減する。
  投票されたときに Posts / Comments から呼ばれる。

  type は "post" または "comment"。
  amount は +1 または -1。

  ## 例
      iex> update_karma(user_id, "post", 1)
      {:ok, %User{}}

      iex> update_karma(user_id, "comment", -1)
      {:ok, %User{}}
  """
  def update_karma(user_id, type, amount) do
    field = karma_field(type)

    {1, [user]} =
      from(u in User, where: u.id == ^user_id, select: u)
      |> Repo.update_all(inc: [{field, amount}])

    {:ok, user}
  end

  # "post" → :post_karma, "comment" → :comment_karma
  defp karma_field("post"),    do: :post_karma
  defp karma_field("comment"), do: :comment_karma
end
