defmodule RedditClone.Reports.Report do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_targets ["post", "comment"]

  @valid_reasons [
    "spam",
    "harassment",
    "hate_speech",
    "misinformation",
    "other"
  ]

  schema "reports" do
    field :reason,      :string
    field :target_type, :string
    field :target_id,   :binary_id

    belongs_to :reporter, RedditClone.Accounts.User

    timestamps(updated_at: false)
  end

  def changeset(report, attrs) do
    report
    |> cast(attrs, [:reason, :reporter_id, :target_type, :target_id])
    |> validate_required([:reason, :reporter_id, :target_type, :target_id])
    |> validate_inclusion(:reason, @valid_reasons)
    |> validate_inclusion(:target_type, @valid_targets)
  end
end
