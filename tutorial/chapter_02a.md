# 第2章　データベース設計とマイグレーション（前編）

---

## 2-1　テーブル設計の考え方

データベースの設計はアプリの土台です。後から変更するとコード全体に影響が出るため、実装前にしっかり考えます。

このアプリでは以下の7つのテーブルを使います。

| テーブル | 役割 |
|---------|------|
| `users` | ユーザーアカウント・Karma |
| `subreddits` | コミュニティ |
| `subreddit_members` | ユーザーとコミュニティの参加関係 |
| `posts` | 投稿（テキスト・リンク） |
| `comments` | コメント・返信 |
| `votes` | 投票（投稿とコメント両方に対応） |
| `reports` | 報告 |

---

### テーブルの依存関係

マイグレーションは依存関係の順番に実行する必要があります。参照先のテーブルが先に存在していなければなりません。

```
① users              ← すべての土台。依存なし
② subreddits         ← users に依存（owner_id）
③ subreddit_members  ← users + subreddits に依存
④ posts              ← users + subreddits に依存
⑤ comments          ← users + posts に依存（自己参照あり）
⑥ votes             ← users に依存
⑦ reports           ← users に依存
```

ファイル名の先頭にタイムスタンプをつけることで、この順番を保証します。

---

### votes と reports の設計について

votes と reports は投稿にもコメントにも紐づきます。この場合、2つの設計方針があります。

**方針A: テーブルを分ける**
```
post_votes    テーブル
comment_votes テーブル
```

**方針B: 1つのテーブルで `target_type` で区別する**
```
votes テーブル
  target_type: "post" | "comment"
  target_id:   対象のID
```

このアプリでは**方針B**を採用します。テーブルが増えず、投票ロジックを1箇所にまとめられるからです。ただし `target_id` は外部キー制約を使えないため、アプリ側でデータの整合性を保証します。

---

## 2-2　マイグレーションファイルを作成する

`priv/repo/migrations/` に以下のコマンドでファイルを生成します。

```bash
mix ecto.gen.migration create_users
mix ecto.gen.migration create_subreddits
mix ecto.gen.migration create_subreddit_members
mix ecto.gen.migration create_posts
mix ecto.gen.migration create_comments
mix ecto.gen.migration create_votes
mix ecto.gen.migration create_reports
```

生成されたファイルに内容を記述していきます。

---

## 2-3　users テーブル

```elixir
# priv/repo/migrations/XXXXXX_create_users.exs
defmodule RedditClone.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :username, :string, null: false
      add :email, :string, null: false
      add :password_hash, :string, null: false
      add :post_karma, :integer, default: 0, null: false
      add :comment_karma, :integer, default: 0, null: false

      timestamps()
    end

    create unique_index(:users, [:username])
    create unique_index(:users, [:email])
  end
end
```

**解説**

`primary_key: false` と `add :id, :binary_id` の組み合わせで、主キーを自動生成の整数ではなく UUID にしています。UUID を使う理由は2つあります。

1. URLに `/users/1` のような連番が露出しない（ユーザー数が推測されない）
2. 将来的に複数サーバーに分散しても ID が衝突しない

`timestamps()` は `inserted_at` と `updated_at` の2カラムを自動的に追加します。

`unique_index` で `username` と `email` の重複を DB レベルで防ぎます。アプリ側のバリデーションだけでは、同時リクエストで重複が起きる可能性があるためです。

---

## 2-4　subreddits テーブル

```elixir
# priv/repo/migrations/XXXXXX_create_subreddits.exs
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
```

**解説**

`references(:users, on_delete: :restrict)` は外部キー制約です。`on_delete: :restrict` はコミュニティのオーナーが削除されようとしたとき、DB がエラーを返してくれます。コミュニティが宙に浮かないようにするための保護です。

`name` に `unique_index` をつけているのは、`r/elixir` のような URL に使われるためです。同じ名前のコミュニティが2つ存在すると URL が衝突します。

`description` は `:text` 型にしています。`:string` は255文字の制限がありますが、`:text` は制限がありません。

---

## 2-5　subreddit_members テーブル

```elixir
# priv/repo/migrations/XXXXXX_create_subreddit_members.exs
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
```

**解説**

`on_delete: :delete_all` はユーザーまたはコミュニティが削除されたとき、関連するメンバーレコードも自動的に削除します。

`unique_index([:user_id, :subreddit_id])` は同じユーザーが同じコミュニティに2回参加できないことを DB レベルで保証します。

`timestamps(updated_at: false)` は `inserted_at`（参加日時）だけを記録します。参加日時は変わらないので `updated_at` は不要です。

`role` カラムは `"member"` または `"moderator"` を格納します。

---

## 2-6　posts テーブル

```elixir
# priv/repo/migrations/XXXXXX_create_posts.exs
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
    create index(:posts, [:hot_score])                    # ホーム Feed
  end
end
```

**解説**

`type` カラムで投稿の種類を区別します。`"text"` のとき `body` を使い、`"link"` のとき `url` を使います。1つのテーブルで2種類の投稿を管理するシンプルな設計です。

`hot_score` は投票数と投稿時刻から計算したランキングスコアです。毎回計算するとコストがかかるため、DB に保存しておきます。

インデックスに注目してください。

```
[:subreddit_id, :hot_score]   → コミュニティページの Hot 順表示
[:subreddit_id, :inserted_at] → コミュニティページの New 順表示
[:hot_score]                  → ホーム Feed の Hot 順表示
```

インデックスがあると、DBが全件を調べずに素早く結果を返せます。大量の投稿があっても高速に動作させるために必要です。

`author_id` の `on_delete: :restrict` はユーザーを削除しようとしたとき、投稿が残っているならエラーを返します。ユーザーが削除されても投稿が見えなくなるだけで、データとして残す設計のためです。

`subreddit_id` の `on_delete: :delete_all` はコミュニティが削除されたとき、そのコミュニティの投稿も全て削除します。

---

後編では `comments`・`votes`・`reports` テーブルとマイグレーションの実行方法を説明します。
