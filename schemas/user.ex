defmodule RedditClone.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field :username,      :string
    field :email,         :string
    field :password_hash, :string
    field :password,      :string, virtual: true  # DBに保存しない（ハッシュ化前）
    field :post_karma,    :integer, default: 0
    field :comment_karma, :integer, default: 0

    has_many :posts,    RedditClone.Posts.Post,      foreign_key: :author_id
    has_many :comments, RedditClone.Comments.Comment, foreign_key: :author_id
    has_many :subreddit_members, RedditClone.Communities.SubredditMember
    has_many :subreddits, through: [:subreddit_members, :subreddit]

    timestamps()
  end

  # 登録用チェンジセット
  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :email, :password])
    |> validate_required([:username, :email, :password])
    |> validate_length(:username, min: 3, max: 20)
    |> validate_format(:username, ~r/^[a-zA-Z0-9_]+$/)   # 英数字とアンダースコアのみ
    |> validate_format(:email, ~r/@/)
    |> validate_length(:password, min: 8)
    |> unique_constraint(:username)
    |> unique_constraint(:email)
    |> put_password_hash()
  end

  # パスワードをハッシュ化してpassword_hashに入れる
  defp put_password_hash(changeset) do
    case get_change(changeset, :password) do
      nil -> changeset
      password -> put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))
    end
  end
end
