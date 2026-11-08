defmodule RedditClone.Comments.Comment do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "comments" do
    field :body,  :string
    field :score, :integer, default: 0

    belongs_to :author,  RedditClone.Accounts.User
    belongs_to :post,    RedditClone.Posts.Post
    belongs_to :parent,  RedditClone.Comments.Comment  # nullable（自己参照）
    has_many   :replies, RedditClone.Comments.Comment,
                         foreign_key: :parent_id       # 再帰

    timestamps()
  end

  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:body, :author_id, :post_id, :parent_id])
    |> validate_required([:body, :author_id, :post_id])
    |> validate_length(:body, min: 1, max: 10_000)
    # parent_id は nullable なのでバリデーション不要
  end
end
