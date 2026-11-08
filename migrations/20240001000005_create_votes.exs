defmodule RedditClone.Repo.Migrations.CreateVotes do
  use Ecto.Migration

  def change do
    create table(:votes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :value, :integer, null: false           # +1 | -1
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :target_type, :string, null: false      # "post" | "comment"
      add :target_id, :binary_id, null: false

      timestamps(updated_at: false)
    end

    # 1人1票の制約
    create unique_index(:votes, [:user_id, :target_type, :target_id])

    create index(:votes, [:target_type, :target_id])            # スコア集計
    create index(:votes, [:user_id, :target_type, :target_id])  # 投票済みチェック
  end
end
