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
    field :body,          :string   # type=text のみ使用
    field :url,           :string   # type=link のみ使用
    field :score,         :integer, default: 0
    field :hot_score,     :float,   default: 0.0
    field :comment_count, :integer, virtual: true, default: 0  # DBには保存しない

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

  # typeによって必須フィールドを切り替える
  defp validate_by_type(changeset) do
    case get_field(changeset, :type) do
      "text" ->
        changeset
        |> validate_required([:body])
        |> validate_length(:body, max: 40_000)

      "link" ->
        changeset
        |> validate_required([:url])
        |> validate_format(:url, ~r/^https?:\/\//)  # http/https のみ

      _ ->
        changeset
    end
  end

  # 作成時のHotスコア初期値を計算する
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

**読み解き**

`comment_count, :integer, virtual: true, default: 0` は DB に存在しない仮想フィールドです。投稿一覧を取得するとき、SQL の `COUNT` でコメント数を集計してこのフィールドに入れます。DB にカラムを追加せずに済みます。

`validate_by_type/1` は `type` によって必須フィールドを切り替えます。テキスト投稿なら `body` が必須、リンク投稿なら `url` が必須です。`case` でパターンマッチを使って分岐します。

ここで使っている `get_field(changeset, :type)` は「今の値を見る」関数です。前編の `get_change/2`（変更された分だけを見る。変更がなければ `nil`）と対になっています。`type` のように「元の値であれ新しい値であれ、とにかく今の種別を知りたい」ときは `get_field`、パスワードのように「変更されたときだけ処理したい」ときは `get_change`、と使い分けます。

`case` の最後の節 `_ ->` は「どれにも当てはまらなかった場合」を受け止める受け皿です。`type` が想定外の値でも落ちずにチェンジセットをそのまま返します。なお、想定外の `type` 自体は、その手前の `validate_inclusion(:type, @valid_types)` がエラーとして記録しています。

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
    belongs_to :parent,  RedditClone.Comments.Comment  # nullable（自己参照）
    has_many   :replies, RedditClone.Comments.Comment,
                         foreign_key: :parent_id       # 再帰

    timestamps()
  end

  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:body, :author_id, :post_id, :parent_id])
    |> validate_required([:body, :author_id, :post_id])
    |> validate_length(:body, min: 1, max: 10_000)
    # parent_id は nullable なのでバリデーション不要
  end
end
```

**読み解き**

Comment スキーマは自分自身を参照しています。

```elixir
belongs_to :parent,  RedditClone.Comments.Comment   # 親コメント
has_many   :replies, RedditClone.Comments.Comment,  # 子コメント
           foreign_key: :parent_id
```

`belongs_to :parent` は「このコメントの親は誰か」を表します。`has_many :replies` は「このコメントへの返信一覧」を表します。同じ Comment モジュールが親にも子にもなれます。

`has_many :replies` の `foreign_key: :parent_id` は、「相手（子コメント）側のどの列が自分を指しているか」の指定です。省略するとモジュール名から `comment_id` という列があるものとして扱われてしまいますが、このテーブルにその列はありません。自己参照では、指す列が `parent_id` であることを明示する必要があります。

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
    |> validate_inclusion(:value, @valid_values)           # +1 か -1 のみ
    |> validate_inclusion(:target_type, @valid_targets)    # "post" か "comment" のみ
    |> unique_constraint([:user_id, :target_type, :target_id])  # 1人1票
  end
end
```

**読み解き**

`@valid_values [1, -1]` で投票値を制限します。`1` が Upvote、`-1` が Downvote です。それ以外の値は `validate_inclusion` が弾きます。

`unique_constraint([:user_id, :target_type, :target_id])` はマイグレーションの `unique_index` と対応します。同じユーザーが同じ対象に2回投票しようとすると、Ecto のエラーとして扱えます。

`target_id` は外部キーではなく、ただの `:binary_id` の列です。第2章で見たとおり、投稿とコメントの両方を1つのテーブルで受ける代わりに、参照の整合性は DB ではなくアプリ側（第4章の投票ロジック）で守る設計になっています。

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

**読み解き**

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

**読み解き**

ここで、Elixir のエラー処理の考え方を押さえておきます。検証の失敗は「例外」ではなく「値」として返ります。

- チェンジセットが正しければ `changeset.valid?` が `true`、間違いがあれば `false` になり、間違いの中身は `changeset.errors` に「どのフィールドが、なぜダメか」のリストとして入っています
- `Repo.insert(changeset)` の結果は、成功なら `{:ok, 構造体}`、失敗なら `{:error, changeset}` というタプルです。呼び出し側はこの2通りを受け分けて処理します

この `{:ok, _}` / `{:error, _}` という形は、第4章の Context、第5章の認証でもずっと使われます。「成功と失敗は、戻り値の形で区別する」がこの本全体の約束です。

もう1つ、`unique_constraint` はこのパイプラインの中では「宣言」だけをしている点に注意してください。重複の実際の照合は、`Repo.insert` の瞬間に DB が行います。だからこそ前編で見たとおり、マイグレーションの `unique_index` と対でなければなりません。

---

## 動作確認（この章の仕上げ）

前提: 第2章のマイグレーションが実行済みで、プロジェクトのフォルダで `iex -S mix` が起動できること。

- [ ] `iex -S mix` で `RedditClone.Accounts.User.registration_changeset(%RedditClone.Accounts.User{}, %{username: "alice", email: "alice@example.com", password: "password123"})` を実行し、結果のチェンジセットの `valid?` が `true` になる
- [ ] 同じ式で `username: "ab"`（3文字未満）に変えると `valid?` が `false` になり、`errors` に `:username` のエラーが入る
- [ ] `RedditClone.Posts.Vote.changeset(%RedditClone.Posts.Vote{}, %{value: 0, user_id: Ecto.UUID.generate(), target_type: "post", target_id: Ecto.UUID.generate()})` を実行すると、`value` についてのエラーが入る（`1` か `-1` しか許可されていないため）
- [ ] `RedditClone.Posts.Post.changeset(%RedditClone.Posts.Post{}, %{title: "テスト", type: "text", author_id: Ecto.UUID.generate(), subreddit_id: Ecto.UUID.generate()})` は、`body` が無いため `valid?` が `false` になる。`body: "本文"` を足すと `true` になる（種別で必須が切り替わることの確認）

---

## よくあるエラーと対処

| 症状 | 原因 | 直し方 |
|------|------|--------|
| フォームから送ったはずの値が保存されない | `cast` の許可リストにそのフィールドが無い（黙って捨てられる） | チェンジセットの `cast` にフィールドを追加する |
| 検証を書いたのに素通りする | `cast` より前に検証を書いた／チェンジセット関数自体が呼ばれていない | パイプの順番（cast → validate）を見直し、呼び出し側が正しいチェンジセット関数を使っているか確認する |
| 重複を保存しようとすると `Ecto.ConstraintError` が上がる | `unique_constraint` に対応する `unique_index` がマイグレーションに無い | 第2章のマイグレーション側に `unique_index` を足し、`unique_constraint` と対にする |
| 保存のときに `updated_at` まわりのエラーが出る | スキーマとマイグレーションで `timestamps` の指定が食い違っている | 両側の `timestamps(updated_at: false)` の有無を揃える |
| 検索条件に `comment_count` を使おうとしてエラーになる | `virtual: true` のフィールドは DB に列が無い | 集計は SQL の `count` で行い、結果を入れる先としてだけ使う（第4章の `select_merge`） |

---

## 確認問題

1. `virtual: true` とはどういう意味ですか。User と Post のスキーマで、それぞれ何のために使われていましたか。
2. `User.registration_changeset` に `username: "ab"` を渡すと、どの検証でエラーになりますか。また、その情報は最終的にどこへ保存されますか（DB ではありません）。
3. `Vote.changeset` に `value: 0` を渡すと何が起きますか。どの検証が、どの値と比べて弾きますか。
4. SubredditMember の `role` に `"admin"` も許可したくなりました。変更する場所はどこですか。DB 側の変更は必要ですか。

---

## まとめと次章へのつながり

この章では以下を完了しました。

```
✅ Ecto スキーマの3つの役割を理解した
✅ 7つのスキーマを実装した
✅ virtual フィールドの使い方を学んだ
✅ チェンジセットのパイプラインを理解した
✅ 自己参照（Comment）の実装方法を学んだ
```

次の章では、これらのスキーマを使って**ビジネスロジック（Context）**を実装します。「投票したとき Karma も更新する」「自分の投稿には投票できない」といったルールをコードで表現します。

---

## 確認問題の答え

1. DB に列を持たず、構造体の中だけで使うフィールドのことです。User では入力されたパスワードを一時的に持つため（ハッシュ化したら役目は終わり）、Post では一覧表示のときに集計したコメント数を入れるために使います。
2. `validate_length(:username, min: 3, max: 20)` でエラーになります。エラーは例外にはならず、チェンジセットの `errors` にリストとしてたまります。`Repo.insert` まで進んでも `{:error, changeset}` が返り、DB には保存されません。
3. `validate_inclusion(:value, @valid_values)` が、`@valid_values`（`[1, -1]`）に含まれない値として弾きます。チェンジセットが `valid? == false` になり、保存されません。
4. 変更するのは SubredditMember スキーマの `@valid_roles` に `"admin"` を足すことだけです。DB 側に列挙型の制約は無い（`role` はただの文字列の列）ため、マイグレーションの変更は不要です。
