# 第2章　データベース設計とマイグレーション（後編）

---

## 2-7　comments テーブル

```elixir
# priv/repo/migrations/XXXXXX_create_comments.exs
defmodule RedditClone.Repo.Migrations.CreateComments do
  use Ecto.Migration

  def change do
    create table(:comments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :body, :text, null: false
      add :score, :integer, default: 0, null: false
      add :author_id, references(:users, type: :binary_id, on_delete: :restrict), null: false
      add :post_id, references(:posts, type: :binary_id, on_delete: :delete_all), null: false
      add :parent_id, references(:comments, type: :binary_id, on_delete: :delete_all)

      timestamps()
    end

    create index(:comments, [:post_id])
    create index(:comments, [:parent_id])
    create index(:comments, [:author_id])
  end
end
```

**解説**

`parent_id` が comments テーブル自身を参照しています。これを**自己参照**と呼びます。

```
コメントA（parent_id: nil）        ← トップレベルのコメント
  └─ コメントB（parent_id: A のID）  ← A への返信
       └─ コメントC（parent_id: B のID）  ← B への返信
```

`parent_id` は `null: false` を指定していないため、`nil` を許容します。`nil` のコメントがトップレベルのコメントです。

`on_delete: :delete_all` は親コメントが削除されたとき、その返信も全て削除します。投稿が削除されたときも同様です。

---

## 2-8　votes テーブル

```elixir
# priv/repo/migrations/XXXXXX_create_votes.exs
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

    create unique_index(:votes, [:user_id, :target_type, :target_id])
    create index(:votes, [:target_type, :target_id])
  end
end
```

**解説**

`target_id` は `:binary_id` 型ですが、`references()` を使っていません。投稿とコメントの両方を指す可能性があるため、外部キー制約をつけられないからです。代わりにアプリ側で正しい `target_id` を渡すことを保証します。

最も重要なのは `unique_index([:user_id, :target_type, :target_id])` です。これが「1人1票」を DB レベルで保証します。同じユーザーが同じ投稿に2回投票しようとすると、DB がエラーを返します。

```
user_id: "alice"
target_type: "post"
target_id: "abc-123"
→ この組み合わせは DB に1件しか存在できない
```

---

## 2-9　reports テーブル

```elixir
# priv/repo/migrations/XXXXXX_create_reports.exs
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
```

**解説**

votes と同じく `target_type` と `target_id` で投稿・コメント両方の報告を1つのテーブルで扱います。

votes と違って `unique_index` をつけていません。同じユーザーが同じ投稿を複数回報告することを許容します。Reddit も同様の設計です。

---

## 2-10　マイグレーションを実行する

7つのファイルを全て記述したら、以下のコマンドで実行します。

```bash
mix ecto.migrate
```

成功すると以下のように表示されます。

```
13:45:00.123 [info] == Running RedditClone.Repo.Migrations.CreateUsers.change/0 forward
13:45:00.125 [info] create table users
13:45:00.145 [info] create index users_username_index
13:45:00.148 [info] create index users_email_index
13:45:00.150 [info] == Migrated 20240001000000 in 0.0s

13:45:00.155 [info] == Running RedditClone.Repo.Migrations.CreateSubreddits.change/0 forward
...（以下続く）
```

7つ全てのマイグレーションが実行されれば完了です。

---

### マイグレーションのやり直し方

間違えた場合はロールバックできます。

```bash
# 1つ前の状態に戻す
mix ecto.rollback

# n ステップ前に戻す
mix ecto.rollback --step 3

# 全てリセットしてやり直す
mix ecto.reset
```

---

## 2-11　テーブルの確認

psql で実際に作成されたテーブルを確認できます。

```bash
psql -d reddit_clone_dev

# テーブル一覧
\dt

# users テーブルの構造
\d users
```

以下のように表示されれば成功です。

```
           List of relations
 Schema |       Name        | Type  |  Owner
--------+-------------------+-------+----------
 public | comments          | table | postgres
 public | posts             | table | postgres
 public | reports           | table | postgres
 public | schema_migrations  | table | postgres
 public | subreddit_members | table | postgres
 public | subreddits        | table | postgres
 public | users             | table | postgres
 public | votes             | table | postgres
```

`schema_migrations` は Ecto が自動的に作るテーブルで、どのマイグレーションが実行済みかを記録しています。

---

## まとめ

この章では以下を完了しました。

```
✅ 7つのテーブルの設計思想を理解した
✅ テーブルの依存関係を把握した
✅ マイグレーションファイルを実装した
✅ インデックスの役割を理解した
✅ マイグレーションを実行した
```

**設計の重要なポイントを振り返ります。**

- 主キーは UUID（`binary_id`）を使う
- `on_delete` でデータの整合性を DB レベルで保証する
- インデックスは「どの順番で表示するか」を考えてつける
- `votes` と `reports` は `target_type` で汎用的に設計する
- `unique_index` で重複を DB レベルで防ぐ

次の章では、これらのテーブルを Elixir の構造体として扱うための **Ecto スキーマ**を実装します。
