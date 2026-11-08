defmodule RedditClone.Posts.Vote do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_values  [1, -1]
  @valid_targets ["post", "comment"]

  schema "votes" do
    field :value,       :integer
    field :target_type, :string
    field :target_id,   :binary_id

    belongs_to :user, RedditClone.Accounts.User

    timestamps(updated_at: false)
  end

  def changeset(vote, attrs) do
    vote
    |> cast(attrs, [:value, :user_id, :target_type, :target_id])
    |> validate_required([:value, :user_id, :target_type, :target_id])
    |> validate_inclusion(:value, @valid_values)           # +1 か -1 のみ
    |> validate_inclusion(:target_type, @valid_targets)    # "post" か "comment" のみ
    |> unique_constraint([:user_id, :target_type, :target_id])  # 1人1票
  end
end
