defmodule RedditClone.Posts.Post do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_types ["text", "link"]

  schema "posts" do
    field :title,         :string
    field :type,          :string
    field :body,          :string   # type=text のみ使用
    field :url,           :string   # type=link のみ使用
    field :score,         :integer, default: 0
    field :hot_score,     :float,   default: 0.0
    field :comment_count, :integer, virtual: true, default: 0  # DBには保存しない

    belongs_to :author,    RedditClone.Accounts.User
    belongs_to :subreddit, RedditClone.Communities.Subreddit
    has_many   :comments,  RedditClone.Comments.Comment
    has_many   :votes,     RedditClone.Posts.Vote

    timestamps()
  end

  def changeset(post, attrs) do
    post
    |> cast(attrs, [:title, :type, :body, :url, :author_id, :subreddit_id])
    |> validate_required([:title, :type, :author_id, :subreddit_id])
    |> validate_length(:title, min: 1, max: 300)
    |> validate_inclusion(:type, @valid_types)
    |> validate_by_type()
    |> put_hot_score()
  end

  # typeによって必須フィールドを切り替える
  defp validate_by_type(changeset) do
    case get_field(changeset, :type) do
      "text" ->
        changeset
        |> validate_required([:body])
        |> validate_length(:body, max: 40_000)

      "link" ->
        changeset
        |> validate_required([:url])
        |> validate_format(:url, ~r/^https?:\/\//)  # http/https のみ

      _ ->
        changeset
    end
  end

  # 作成時のHotスコア初期値を計算する
  defp put_hot_score(changeset) do
    put_change(changeset, :hot_score, compute_hot_score(0, DateTime.utc_now()))
  end

  def compute_hot_score(score, inserted_at) do
    epoch = ~U[2005-12-08 07:46:43Z]

    sign =
      cond do
        score > 0 -> 1
        score < 0 -> -1
        true -> 0
      end

    order = :math.log10(max(abs(score), 1))
    seconds = DateTime.diff(inserted_at, epoch)
    sign * order + seconds / 45_000
  end
end
