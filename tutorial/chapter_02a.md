# 第2章　データベース設計とマイグレーション（前編）

---

### この章で学ぶこと

- 作るもの: 7つのテーブル（users、subreddits、subreddit_members、posts、comments、votes、reports）と、そのマイグレーションファイル。前編では users から posts までの4つ、後編では残り3つと実行の手順を扱います
- 学ぶ考え方: マイグレーションという考え方、主キーを UUID にする理由、外部キーと `on_delete` の選び方、インデックスと一意制約の役割、変更を戻す（ロールバック）ときの考え方

### 前提

- 第1章が済んでいること（プロジェクトが生成され、`mix ecto.create` でデータベースが作られていること）
- PostgreSQL が起動していること

### 全体の中での位置

この章は、3層構造のいちばん下、Data 層の土台を作る章です。まだ画面もビジネスロジックも作りません。「どんなデータを、どんな形で保存するか」を先に固めることで、第3章のスキーマ、第4章の Context がその上に積めるようになります。

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

**読み解き**

マイグレーションとは、「データベースの形の変更を、順番つきの手順として記録したもの」です。テーブルを直接手で作るのではなく、手順をファイルに書いて実行する形にすると、同じ手順を別のパソコンでも再現でき、間違えたときに戻すこともできます。

各マイグレーションファイルの中身は `change` という関数1つです。「テーブルを作る」「列を足す」「インデックスを作る」といった命令を、`change` の中に上から順に書きます。実行すると上から順に進み、戻す（ロールバックする）ときは、Ecto がその逆の手順を組み立てます。たとえば「テーブルを作る」の逆は「テーブルを消す」です。

実行済みのマイグレーションは、データベースの中の `schema_migrations` という記録用のテーブルに控えられます。そのため、`mix ecto.migrate` を2回実行しても、2回目は「実行済み」として何も起きません。何度実行しても結果が同じになる性質を「冪等（べきとう）」と呼びます。逆に、すでに実行済みのファイルの中身を書き換えても、データベースには反映されません。直したいときは、いったん戻してから直すか、新しいマイグレーションを足すのが決まりです（後編の 2-10 で手順を見ます）。

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

なお、この章の本文ではファイル名を `XXXXXX_create_users.exs` のように仮の印で書いています。実際のファイル名の先頭には、生成した日時の数字（タイムスタンプ）が入ります。この本の完成コードでは `20240001000000_create_users.exs` から `20240001000006_create_reports.exs` までの連番になっています。読者の環境で生成すると数字はそのときの日時になりますが、困ることはありません。大切なのは数字そのものではなく、依存関係の順番どおりに並ぶことです。対応は次のとおりです。

| 本文の仮名 | 完成コードのファイル |
|-----------|-------------------|
| `XXXXXX_create_users` | `20240001000000_create_users` |
| `XXXXXX_create_subreddits` | `20240001000001_create_subreddits` |
| `XXXXXX_create_subreddit_members` | `20240001000002_create_subreddit_members` |
| `XXXXXX_create_posts` | `20240001000003_create_posts` |
| `XXXXXX_create_comments` | `20240001000004_create_comments` |
| `XXXXXX_create_votes` | `20240001000005_create_votes` |
| `XXXXXX_create_reports` | `20240001000006_create_reports` |

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

**読み解き**

`primary_key: false` と `add :id, :binary_id` の組み合わせで、主キーを自動生成の整数ではなく UUID にしています。UUID を使う理由は2つあります。

1. URLに `/users/1` のような連番が露出しない（ユーザー数が推測されない）
2. 将来的に複数サーバーに分散しても ID が衝突しない

`timestamps()` は `inserted_at` と `updated_at` の2カラムを自動的に追加します。

`unique_index` で `username` と `email` の重複を DB レベルで防ぎます。アプリ側のバリデーションだけでは、同時リクエストで重複が起きる可能性があるためです。

もう少しだけ深く見ます。`:binary_id` は、UUID をデータベースに保存するときの型の名前です。新しい行を保存すると、Ecto が UUID を自動で作って `id` に入れるので、コード側で採番する必要はありません。

`null: false` は「この列は空ではいけない」、`default: 0` は「値を指定しなかったときの最初の値」という指定です。この2つは似て非なるものです。`null: false` だけでは、空でなければ何でも入ってしまいますし、`default` だけでは、明示的に空を入れようとしたとき止められません。Karma のように「必ず数値で、最初は 0」という列には、両方を指定します。

`unique_index` と、次に出てくる通常の `index` の違いも大切です。`index` は探す速さのための仕掛け、`unique_index` は速さに加えて「同じ値の組み合わせは1件だけ」という制約を兼ねます。制約として効かせたいときは、必ず `unique_index` のほうです。

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

**読み解き**

`references(:users, on_delete: :restrict)` は外部キー制約です。`on_delete: :restrict` はコミュニティのオーナーが削除されようとしたとき、DB がエラーを返してくれます。コミュニティが宙に浮かないようにするための保護です。

`name` に `unique_index` をつけているのは、`r/elixir` のような URL に使われるためです。同じ名前のコミュニティが2つ存在すると URL が衝突します。

`description` は `:text` 型にしています。`:string` は255文字の制限がありますが、`:text` は制限がありません。

外部キーの読み方も押さえます。`references(:users, type: :binary_id, on_delete: :restrict)` の `type: :binary_id` は、「参照先の主キーが UUID なので、こちらも同じ型で持つ」という合わせ方の指定です。型が合っていないと、外部キー自体が作れません。

`on_delete` は、この先のテーブルでも何度も出てくる、設計の分かれ目です。意味は「参照先の行が消えたとき、この行をどうするか」で、代表的な選択は次の3つです。

- `:restrict` — 参照先を消すこと自体を止める（この節の owner がそう）
- `:delete_all` — 紐づく行も一緒に消す（次の subreddit_members の両端がそう）
- 指定なし — 何もしない。参照先が消えると、このアプリでは外部キーの検査でエラーになる場合があります

どれが正しいかは「親が消えたら子はどうなるのが自然か」で決まります。コミュニティの作成者が消えてもコミュニティを宙に浮かせたくないので `:restrict`、参加の記録は参加者やコミュニティが消えれば意味を失うので `:delete_all`、という具合です。

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

**読み解き**

`on_delete: :delete_all` はユーザーまたはコミュニティが削除されたとき、関連するメンバーレコードも自動的に削除します。

`unique_index([:user_id, :subreddit_id])` は同じユーザーが同じコミュニティに2回参加できないことを DB レベルで保証します。

`timestamps(updated_at: false)` は `inserted_at`（参加日時）だけを記録します。参加日時は変わらないので `updated_at` は不要です。

`role` カラムは `"member"` または `"moderator"` を格納します。

このテーブルは「中間テーブル」と呼ばれる定番の形です。ユーザーとコミュニティは、どちらから見ても相手が複数いる関係（多対多）なので、関係そのものを1つのテーブルに切り出しています。切り出したおかげで、`role`（役割）や参加日時（`inserted_at`）のような「関係に付く情報」を置く場所ができました。第4章の参加・脱退の処理は、このテーブルへの追加と削除として書かれます。

複合の `unique_index([:user_id, :subreddit_id])` は「列の組み合わせで1件だけ」という意味です。`user_id` だけ、あるいは `subreddit_id` だけが重なるのは普通のことなので、単独の列には付けません。間違えやすい点です。

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
    create index(:posts, [:hot_score])                    # ホームFeed
  end
end
```

**読み解き**

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

複合インデックス（列が2つあるインデックス）の読み方も押さえておきます。`[:subreddit_id, :hot_score]` は「まず `subreddit_id` で絞り、その中で `hot_score` の順に並べる」ときに効きます。並びの左側の列が先に効くので、列の順番自体が意味を持ちます。逆向きの `[:hot_score, :subreddit_id]` では、コミュニティごとに絞る使い方には効きにくくなります。

インデックスは万能ではありません。付けた分だけ、行を追加・更新するときの手間が増えます。「どの画面で、どの順番で表示するか」が決まっている場所にだけ付けるのが原則で、このテーブルの3つの複合・単独インデックスは、第6章の Feed の表示順と対応しています。

---

後編では `comments`・`votes`・`reports` テーブルとマイグレーションの実行方法を説明します。
