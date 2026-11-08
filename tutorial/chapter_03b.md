# 第3章　Ecto スキーマ（後編）

---

## 3-6　Post スキーマ

```elixir
# lib/reddit_clone/posts/post.ex
defmodule RedditClone.Posts.Post do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_types ["text", "link"]

  schema "posts" do
    field :title,         :string
    field :type,          :string
    field :body,          :string
    field :url,           :string
    field :score,         :integer, default: 0
    field :hot_score,     :float,   default: 0.0
    field :comment_count, :integer, virtual: true, default: 0

    belongs_to :author,    RedditClone.Accounts.User
    belongs_to :subreddit, RedditClone.Communities.Subreddit
    has_many   :comments,  RedditClone.Comments.Comment
    has_many   :votes,     RedditClone.Posts.Vote

    timestamps()
  end

  def changeset(post, attrs) do
    post
    |> cast(attrs, [:title, :type, :body, :url, :author_id, :subreddit_id])
    |> validate_required([:title, :type, :author_id, :subreddit_id])
    |> validate_length(:title, min: 1, max: 300)
    |> validate_inclusion(:type, @valid_types)
    |> validate_by_type()
    |> put_hot_score()
  end

  defp validate_by_type(changeset) do
    case get_field(changeset, :type) do
      "text" ->
        changeset
        |> validate_required([:body])
        |> validate_length(:body, max: 40_000)

      "link" ->
        changeset
        |> validate_required([:url])
        |> validate_format(:url, ~r/^https?:\/\//)

      _ ->
        changeset
    end
  end

  defp put_hot_score(changeset) do
    put_change(changeset, :hot_score, compute_hot_score(0, DateTime.utc_now()))
  end

  def compute_hot_score(score, inserted_at) do
    epoch = ~U[2005-12-08 07:46:43Z]
    order = :math.log10(max(abs(score), 1))
    seconds = DateTime.diff(inserted_at, epoch)
    order + seconds / 45_000
  end
end
```

**解説**

`comment_count, :integer, virtual: true, default: 0` は DB に存在しない仮想フィールドです。投稿一覧を取得するとき、SQL の `COUNT` でコメント数を集計してこのフィールドに入れます。DB にカラムを追加せずに済みます。

`validate_by_type/1` は `type` によって必須フィールドを切り替えます。テキスト投稿なら `body` が必須、リンク投稿なら `url` が必須です。`case` でパターンマッチを使って分岐します。

`compute_hot_score/2` は Reddit のオリジナルアルゴリズムをシンプルにしたものです。

```elixir
order = :math.log10(max(abs(score), 1))  # スコアの対数（急激な差をなだらかにする）
seconds = DateTime.diff(inserted_at, epoch)  # 基準時刻からの秒数
order + seconds / 45_000                 # 時間経過で自然に下がる
```

投稿されてから時間が経つほど `hot_score` が相対的に下がり、新しい投稿が上位に来やすくなります。

---

## 3-7　Comment スキーマ

```elixir
# lib/reddit_clone/comments/comment.ex
defmodule RedditClone.Comments.Comment do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "comments" do
    field :body,  :string
    field :score, :integer, default: 0

    belongs_to :author,  RedditClone.Accounts.User
    belongs_to :post,    RedditClone.Posts.Post
    belongs_to :parent,  RedditClone.Comments.Comment
    has_many   :replies, RedditClone.Comments.Comment,
                         foreign_key: :parent_id

    timestamps()
  end

  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:body, :author_id, :post_id, :parent_id])
    |> validate_required([:body, :author_id, :post_id])
    |> validate_length(:body, min: 1, max: 10_000)
  end
end
```

**解説**

Comment スキーマは自分自身を参照しています。

```elixir
belongs_to :parent,  RedditClone.Comments.Comment   # 親コメント
has_many   :replies, RedditClone.Comments.Comment,  # 子コメント
           foreign_key: :parent_id
```

`belongs_to :parent` は「このコメントの親は誰か」を表します。`has_many :replies` は「このコメントへの返信一覧」を表します。同じ Comment モジュールが親にも子にもなれます。

`parent_id` は `validate_required` に含めていません。`nil` を許容することでトップレベルのコメントを表現するためです。

---

## 3-8　Vote スキーマ

```elixir
# lib/reddit_clone/posts/vote.ex
defmodule RedditClone.Posts.Vote do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_values  [1, -1]
  @valid_targets ["post", "comment"]

  schema "votes" do
    field :value,       :integer
    field :target_type, :string
    field :target_id,   :binary_id

    belongs_to :user, RedditClone.Accounts.User

    timestamps(updated_at: false)
  end

  def changeset(vote, attrs) do
    vote
    |> cast(attrs, [:value, :user_id, :target_type, :target_id])
    |> validate_required([:value, :user_id, :target_type, :target_id])
    |> validate_inclusion(:value, @valid_values)
    |> validate_inclusion(:target_type, @valid_targets)
    |> unique_constraint([:user_id, :target_type, :target_id])
  end
end
```

**解説**

`@valid_values [1, -1]` で投票値を制限します。`1` が Upvote、`-1` が Downvote です。それ以外の値は `validate_inclusion` が弾きます。

`unique_constraint([:user_id, :target_type, :target_id])` はマイグレーションの `unique_index` と対応します。同じユーザーが同じ対象に2回投票しようとすると、Ecto のエラーとして扱えます。

---

## 3-9　Report スキーマ

```elixir
# lib/reddit_clone/reports/report.ex
defmodule RedditClone.Reports.Report do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_targets ["post", "comment"]
  @valid_reasons [
    "spam",
    "harassment",
    "hate_speech",
    "misinformation",
    "other"
  ]

  schema "reports" do
    field :reason,      :string
    field :target_type, :string
    field :target_id,   :binary_id

    belongs_to :reporter, RedditClone.Accounts.User

    timestamps(updated_at: false)
  end

  def changeset(report, attrs) do
    report
    |> cast(attrs, [:reason, :reporter_id, :target_type, :target_id])
    |> validate_required([:reason, :reporter_id, :target_type, :target_id])
    |> validate_inclusion(:reason, @valid_reasons)
    |> validate_inclusion(:target_type, @valid_targets)
  end
end
```

**解説**

`@valid_reasons` で報告理由を定数として定義します。UI のセレクトボックスと同じ値を使います。アプリ側でリストを変更するとき1箇所だけ修正すれば済みます。

`belongs_to :reporter` は `reporter_id` カラムと `users` テーブルを対応させます。`belongs_to :user` ではなく `belongs_to :reporter` という名前にすることで、「誰が報告したか」という意味が明確になります。

---

## 3-10　チェンジセットのパイプライン

全てのスキーマでチェンジセットはパイプラインで書きます。

```elixir
user
|> cast(attrs, [:username, :email, :password])   # 許可フィールドを取り出す
|> validate_required([:username, :email])         # 必須チェック
|> validate_length(:username, min: 3, max: 20)   # 文字数チェック
|> validate_format(:username, ~r/^[a-z]+$/)      # 形式チェック
|> unique_constraint(:email)                     # 重複チェック（DB レベル）
|> put_password_hash()                           # 変換処理
```

各関数は `changeset` を受け取り、`changeset` を返します。エラーが起きても処理は止まらず、エラーが蓄積された `changeset` が返ってきます。最後に `Repo.insert()` を呼ぶとき、エラーがあれば `{:error, changeset}` が返り、DB への保存は行われません。

---

## まとめ

この章では以下を完了しました。

```
✅ Ecto スキーマの3つの役割を理解した
✅ 7つのスキーマを実装した
✅ virtual フィールドの使い方を学んだ
✅ チェンジセットのパイプラインを理解した
✅ 自己参照（Comment）の実装方法を学んだ
```

次の章では、これらのスキーマを使って**ビジネスロジック（Context）**を実装します。「投票したとき Karma も更新する」「自分の投稿には投票できない」といったルールをコードで表現します。
