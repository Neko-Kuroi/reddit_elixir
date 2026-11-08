defmodule RedditClone.Repo.Migrations.CreateSubreddits do
  use Ecto.Migration

  def change do
    create table(:subreddits, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :owner_id, references(:users, type: :binary_id, on_delete: :restrict), null: false

      timestamps()
    end

    create unique_index(:subreddits, [:name])
    create index(:subreddits, [:owner_id])
  end
end
