defmodule RedditClone.Communities.Subreddit do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "subreddits" do
    field :name,        :string
    field :description, :string

    belongs_to :owner, RedditClone.Accounts.User
    has_many :posts,   RedditClone.Posts.Post
    has_many :subreddit_members, RedditClone.Communities.SubredditMember
    has_many :members, through: [:subreddit_members, :user]

    timestamps()
  end

  def changeset(subreddit, attrs) do
    subreddit
    |> cast(attrs, [:name, :description, :owner_id])
    |> validate_required([:name, :owner_id])
    |> validate_length(:name, min: 3, max: 21)
    |> validate_format(:name, ~r/^[a-zA-Z0-9_]+$/)  # r/○○ の部分
    |> validate_length(:description, max: 500)
    |> unique_constraint(:name)
  end
end
