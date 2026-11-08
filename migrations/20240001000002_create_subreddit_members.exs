defmodule RedditClone.Repo.Migrations.CreateSubredditMembers do
  use Ecto.Migration

  def change do
    create table(:subreddit_members, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :subreddit_id, references(:subreddits, type: :binary_id, on_delete: :delete_all), null: false
      add :role, :string, default: "member", null: false

      timestamps(updated_at: false)
    end

    create unique_index(:subreddit_members, [:user_id, :subreddit_id])
    create index(:subreddit_members, [:user_id])
    create index(:subreddit_members, [:subreddit_id])
  end
end
