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
      add :parent_id, references(:comments, type: :binary_id, on_delete: :delete_all)  # nullable（自己参照）

      timestamps()
    end

    create index(:comments, [:post_id])
    create index(:comments, [:parent_id])
    create index(:comments, [:author_id])
  end
end
```

**読み解き**

`parent_id` が comments テーブル自身を参照しています。これを**自己参照**と呼びます。

```
コメントA（parent_id: nil）        ← トップレベルのコメント
  └─ コメントB（parent_id: A のID）  ← A への返信
       └─ コメントC（parent_id: B のID）  ← B への返信
```

`parent_id` は `null: false` を指定していないため、`nil` を許容します。`nil` のコメントがトップレベルのコメントです。

`on_delete: :delete_all` は親コメントが削除されたとき、その返信も全て削除します。投稿が削除されたときも同様です。

自己参照の読み方を、もう一歩だけ進めます。この設計では、コメント同士の親子関係は「子の側が親の ID を持つ」形で表します。親が子の ID を集めて持つのではありません。こうしておくと、返信を付けるときは「親の ID を書いた行を1つ足す」だけで済み、深さに制限も生まれません。第4章では、このフラットな行の集まりを、表示用に木（ツリー）の形へ組み立て直します。

また、`parent_id` に `on_delete: :delete_all` があるため、親を消すと返信の連なりがまとめて消えます。第4章の削除の処理で、子コメントを1つずつ消すコードを書かなくてよいのは、この指定のおかげです。

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

    # 1人1票の制約
    create unique_index(:votes, [:user_id, :target_type, :target_id])

    create index(:votes, [:target_type, :target_id])            # スコア集計
    create index(:votes, [:user_id, :target_type, :target_id])  # 投票済みチェック
  end
end
```

**読み解き**

`target_id` は `:binary_id` 型ですが、`references()` を使っていません。投稿とコメントの両方を指す可能性があるため、外部キー制約をつけられないからです。代わりにアプリ側で正しい `target_id` を渡すことを保証します。

最も重要なのは `unique_index([:user_id, :target_type, :target_id])` です。これが「1人1票」を DB レベルで保証します。同じユーザーが同じ投稿に2回投票しようとすると、DB がエラーを返します。

```
user_id: "alice"
target_type: "post"
target_id: "abc-123"
→ この組み合わせは DB に1件しか存在できない
```

通常の `index` が2つある理由も、それぞれの使い道と対応しています。`[:target_type, :target_id]` は「この投稿への投票を集める（スコア集計）」用、`[:user_id, :target_type, :target_id]` は「この人はもう投票したかを確かめる」用です。`unique_index` と並びが似ていますが、こちらは制約のためではなく、探す速さのためのものです。

外部キーが無いことの代償も、正直に書いておきます。存在しない投稿の ID を `target_id` に書いても、データベースは止めてくれません。だからこそ第4章の投票の処理では、「対象を取得してから投票を記録する」という順番を守ります。制約で守れない分は、処理の順番で守る、という設計です。

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

**読み解き**

votes と同じく `target_type` と `target_id` で投稿・コメント両方の報告を1つのテーブルで扱います。

votes と違って `unique_index` をつけていません。同じユーザーが同じ投稿を複数回報告することを許容します。Reddit も同様の設計です。

votes と reports は形がよく似ているので、違いを比べると設計の意図が見えます。votes は「1人1票」というルールが本体なので、重複そのものを制約で止めます。reports は「何件報告が来たか」も情報のうちなので、重複を止めません。インデックスは「必ずそうでなければならない決まり」を表すためにつけるもので、決まりではないものにはつけない、という使い分けです。

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

**読み解き**

ロールバックの考え方を押さえます。`change` で書かれたマイグレーションは、「作る」の逆が「消す」、「足す」の逆が「取り除く」というように、Ecto が逆向きの手順を自動で組み立てられる範囲では、そのまま戻せます。ただし、列の型を変える、データを書き換える、といった「逆が一意に決まらない変更」は、`change` では戻せません。その場合は `up` と `down` という2つの関数を分けて書き、進むときと戻るときの手順を両方とも自分で書きます。この本のマイグレーションは、すべて `change` で戻せる範囲の変更です。

`mix ecto.reset` は強い命令です。データベースを丸ごと捨てて、作り直し、マイグレーションを流し直します（このプロジェクトの設定では、初期データの投入も続けて動きます）。中に入っているデータは消えるので、使うのは「まだ作りかけで、データに未練がないとき」だけです。間違えたファイルが1つだけなら、まず `mix ecto.rollback` で1つ戻すのが先です。

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

## 動作確認（この章の仕上げ）

前提は、PostgreSQL が起動していて、第1章でデータベースが作られていることです。

- [ ] `mix ecto.migrate` を実行すると、7つのマイグレーション全てに「== Migrated」と表示される
- [ ] もう一度 `mix ecto.migrate` を実行しても、新しく実行されるものが無い（実行済みとして扱われる）
- [ ] psql の `\dt` で、users、subreddits、subreddit_members、posts、comments、votes、reports の7テーブルと、`schema_migrations` が見える
- [ ] `\d users` で、`id` が `uuid` 型になっていることと、`username` と `email` に UNIQUE のインデックスがあることが見える
- [ ] `\d posts` で、`subreddit_id` と `hot_score` の複合インデックスが見える

---

## よくあるエラーと対処

| 症状 | 原因 | 直し方 |
|------|------|--------|
| マイグレーションで「relation "users" does not exist」のような参照エラーが出る | 実行の順番が依存関係と逆になっている（参照先のテーブルがまだ無い） | ファイル名の先頭の数字が、2-1 の依存関係の順番どおりに並んでいるか確認する |
| 「relation "users" already exists」と出る | 同じマイグレーションが二重に実行されようとしている、または手で作ったテーブルが残っている | `schema_migrations` の記録と実際のテーブルを確認する。作りかけの段階なら `mix ecto.reset` でやり直すのも手です |
| ファイルを直したのに、実行しても変わらない | すでに実行済みのマイグレーションは再実行されない（記録が残っているため） | `mix ecto.rollback` で戻してから直すか、新しいマイグレーションを足す |
| 保存のときに外部キーのエラー（foreign key constraint）が出る | 存在しない ID を参照しようとしている | 参照先の行が先に作られているか、渡している ID が正しいかを確認する |
| 一意制約のエラー（unique constraint）が出る | `unique_index` のある組み合わせが重なっている | 重複が起きた組み合わせ（例: 同じユーザーの同じコミュニティへの参加）を確認する。仕様どおりの重なりなら、アプリ側で先に確かめる書き方が必要です |

---

## 確認問題

1. 主キーを連番の整数ではなく UUID にしている理由を、2つ挙げてください。
2. `subreddits` の `owner_id` は `on_delete: :restrict`、`subreddit_members` の両端は `on_delete: :delete_all` です。この違いは、何を基準に決められていますか。
3. `mix ecto.migrate` を2回実行しても、2回目は何も起きません。なぜですか。また、その性質を何と呼びますか。
4. コミュニティページで「そのコミュニティの投稿を Hot 順に」表示するときに効くのは、posts のどのインデックスですか。列の並びの順番が大切なのはなぜですか。
5. votes には `unique_index` があるのに、reports にはありません。この違いは、それぞれの「決まり」の何を表していますか。

---

## まとめと次章へのつながり

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

次の章では、これらのテーブルを Elixir の構造体として扱うための **Ecto スキーマ**を実装します。この章で決めた列の名前・型・制約が、そのままスキーマの土台になります。特に主キーが UUID であることと、`parent_id` の自己参照は、第3章でもう一度出てきます。

---

## 確認問題の答え

1. 連番だと URL から総数が推測されてしまうことと、将来サーバーを分散したときに番号が衝突することです（2-3）。
2. 「親が消えたとき、子はどうなるのが自然か」が基準です。作成者が消えてもコミュニティを宙に浮かせないため `:restrict`、参加の記録は参加者やコミュニティが消えれば意味を失うため `:delete_all` です（2-4、2-5）。
3. 実行済みのマイグレーションは `schema_migrations` に記録されていて、再実行の対象から外れるからです。何度実行しても結果が同じになる性質を「冪等」と呼びます（2-1 の読み解き）。
4. `[:subreddit_id, :hot_score]` の複合インデックスです。複合インデックスは左側の列から先に効くため、「コミュニティで絞ってから Hot 順」という使い方には、この並びでないと効きにくいからです（2-6）。
5. votes は「1人1票」が守るべき決まりそのものなので制約で止め、reports は「何件報告が来たか」も情報なので重複を許す、という違いです（2-8、2-9）。
