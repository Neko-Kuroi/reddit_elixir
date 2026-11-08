defmodule RedditClone.Repo.Migrations.CreateReports do
  use Ecto.Migration

  def change do
    create table(:reports, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :reason, :string, null: false
      add :reporter_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :target_type, :string, null: false    # "post" | "comment"
      add :target_id, :binary_id, null: false

      timestamps(updated_at: false)
    end

    create index(:reports, [:target_type, :target_id])
    create index(:reports, [:reporter_id])
  end
end
