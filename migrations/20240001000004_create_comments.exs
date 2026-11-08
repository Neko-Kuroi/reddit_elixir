defmodule RedditClone.Repo.Migrations.CreateComments do
  use Ecto.Migration

  def change do
    create table(:comments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :body, :text, null: false
      add :score, :integer, default: 0, null: false
      add :author_id, references(:users, type: :binary_id, on_delete: :restrict), null: false
      add :post_id, references(:posts, type: :binary_id, on_delete: :delete_all), null: false
      add :parent_id, references(:comments, type: :binary_id, on_delete: :delete_all)  # nullable（自己参照）

      timestamps()
    end

    create index(:comments, [:post_id])
    create index(:comments, [:parent_id])
    create index(:comments, [:author_id])
  end
end
