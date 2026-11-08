defmodule RedditClone.Communities.SubredditMember do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_roles ["member", "moderator"]

  schema "subreddit_members" do
    field :role, :string, default: "member"

    belongs_to :user,      RedditClone.Accounts.User
    belongs_to :subreddit, RedditClone.Communities.Subreddit

    timestamps(updated_at: false)
  end

  def changeset(member, attrs) do
    member
    |> cast(attrs, [:user_id, :subreddit_id, :role])
    |> validate_required([:user_id, :subreddit_id])
    |> validate_inclusion(:role, @valid_roles)
    |> unique_constraint([:user_id, :subreddit_id])  # 1人1回のみJoin可能
  end
end
