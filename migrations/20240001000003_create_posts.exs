defmodule RedditClone.Repo.Migrations.CreatePosts do
  use Ecto.Migration

  def change do
    create table(:posts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :type, :string, null: false           # "text" | "link"
      add :body, :text                          # type=text のみ
      add :url, :string                         # type=link のみ
      add :score, :integer, default: 0, null: false
      add :hot_score, :float, default: 0.0, null: false
      add :author_id, references(:users, type: :binary_id, on_delete: :restrict), null: false
      add :subreddit_id, references(:subreddits, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:posts, [:author_id])
    create index(:posts, [:subreddit_id])
    create index(:posts, [:subreddit_id, :hot_score])     # Hot Feed
    create index(:posts, [:subreddit_id, :inserted_at])   # New Feed
    create index(:posts, [:hot_score])                    # ホームFeed
  end
end
