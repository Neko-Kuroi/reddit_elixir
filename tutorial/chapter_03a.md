# 第3章　Ecto スキーマ（前編）

---

### この章で学ぶこと

- 作るもの: 7つの Ecto スキーマ（User、Subreddit、SubredditMember、Post、Comment、Vote、Report）。前編では User・Subreddit・SubredditMember、後編では残りの4つを扱います
- 学ぶ考え方: スキーマと構造体の対応、チェンジセット（保存前の検証）の仕組み、パイプ演算子で検証を組み立てる書き方、アソシエーション（テーブル同士の関係）の表し方

### 前提

- 第2章が済んでいること（7つのテーブルがマイグレーションで作られていること）
- 第1章のセットアップが済み、データベースが作られていること

### 全体の中での位置

この章は Data 層の続きです。第2章で作った「データベースの中の表」に、Elixir のコードから触るための対応付けをします。ここで作るスキーマは、次章の Context（ビジネスロジック）から使われます。画面（LiveView）がスキーマを直接触ることはありません。

---

## 3-1　Ecto スキーマとは

マイグレーションで作ったテーブルはまだ「データベースの中の表」にすぎません。Elixir のコードからテーブルを操作するには、テーブルと Elixir の構造体を対応させる必要があります。その対応を定義するのが **Ecto スキーマ**です。

Ecto スキーマには3つの役割があります。

**役割① テーブルと構造体の対応**

```elixir
schema "users" do
  field :username, :string
  field :email,    :string
end
```

これを書くと、DB の `users` テーブルの1行が Elixir の `%User{}` 構造体として扱えます。

```elixir
# DB から取得するとこういう形になる
%User{
  id: "abc-123",
  username: "alice",
  email: "alice@example.com"
}
```

**役割② アソシエーション（テーブル間の関係）**

```elixir
schema "posts" do
  belongs_to :author, User     # posts.author_id → users.id
  has_many   :comments, Comment # comments.post_id → posts.id
end
```

`belongs_to` と `has_many` で外部キーの関係を表現します。

**役割③ チェンジセット（保存前の検証）**

```elixir
def changeset(user, attrs) do
  user
  |> cast(attrs, [:username, :email])
  |> validate_required([:username, :email])
  |> validate_length(:username, min: 3)
  |> unique_constraint(:email)
end
```

DB に保存する前に「必須項目が入っているか」「文字数は適切か」などを検証します。

---

## 3-2　ファイルの置き場所

スキーマのファイルは Context のディレクトリ内に置きます。

```
lib/reddit_clone/
  ├─ accounts/
  │   └─ user.ex              ← User スキーマ
  ├─ communities/
  │   ├─ subreddit.ex         ← Subreddit スキーマ
  │   └─ subreddit_member.ex  ← SubredditMember スキーマ
  ├─ posts/
  │   ├─ post.ex              ← Post スキーマ
  │   ├─ vote.ex              ← Vote スキーマ
  │   └─ report.ex            ← Report スキーマ  ※ Reports.Report
  └─ comments/
      └─ comment.ex           ← Comment スキーマ
```

---

## 3-3　User スキーマ

```elixir
# lib/reddit_clone/accounts/user.ex
defmodule RedditClone.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field :username,      :string
    field :email,         :string
    field :password_hash, :string
    field :password,      :string, virtual: true  # DBに保存しない（ハッシュ化前）
    field :post_karma,    :integer, default: 0
    field :comment_karma, :integer, default: 0

    has_many :posts,    RedditClone.Posts.Post,      foreign_key: :author_id
    has_many :comments, RedditClone.Comments.Comment, foreign_key: :author_id
    has_many :subreddit_members, RedditClone.Communities.SubredditMember
    has_many :subreddits, through: [:subreddit_members, :subreddit]

    timestamps()
  end

  # 登録用チェンジセット
  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :email, :password])
    |> validate_required([:username, :email, :password])
    |> validate_length(:username, min: 3, max: 20)
    |> validate_format(:username, ~r/^[a-zA-Z0-9_]+$/)   # 英数字とアンダースコアのみ
    |> validate_format(:email, ~r/@/)
    |> validate_length(:password, min: 8)
    |> unique_constraint(:username)
    |> unique_constraint(:email)
    |> put_password_hash()
  end

  # パスワードをハッシュ化してpassword_hashに入れる
  defp put_password_hash(changeset) do
    case get_change(changeset, :password) do
      nil -> changeset
      password -> put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))
    end
  end
end
```

**読み解き**

`@primary_key {:id, :binary_id, autogenerate: true}` はマイグレーションで UUID を使ったことに対応する設定です。全スキーマに必要です。`@primary_key` のように `@` で始まるものは**モジュール属性**と呼び、そのモジュールの中で使う定数を置く場所です（3-5 で `@valid_roles` という形でも出てきます）。

`field :password, :string, virtual: true` の `virtual: true` は重要です。このフィールドはユーザーが入力したパスワードを一時的に保持するためのものです。DB には保存されません。代わりに `put_password_hash/1` がハッシュ化して `password_hash` に入れます。

`validate_format(:username, ~r/^[a-zA-Z0-9_]+$/)` は正規表現でユーザー名の形式を検証します。英数字とアンダースコアのみを許可します。`~r/.../` という書き方は**シジル**と呼ばれる記法で、正規表現そのものを表します。

`get_change(changeset, :password)` は「パスワードが変更されたか」を確認します。`nil` のとき（変更なし）はハッシュ化をスキップします。

チェンジセットとパイプの読み方も、ここで押さえておきます。

`registration_changeset/2` の中身は、上から下へ流れるパイプラインです。パイプ演算子 `|>` は「左側の値を、右側の関数の第1引数に入れる」という意味です。つまり `user |> cast(attrs, [:username, ...])` は `cast(user, attrs, [:username, ...])` と同じで、「元のデータ → 取り込み → 検証 → 検証 → …」という加工の流れを、上から順に読めます。

そして各段で受け渡しされているのが**チェンジセット**です。チェンジセットは「元のデータ」「変更しようとしている内容（changes）」「見つかったエラーの一覧」をひとまとめに持った構造体です。大切なのは、検証でエラーが見つかっても処理が止まらないことです。エラーはチェンジセットの中にたまっていき、最後まで流れます。途中で例外で落ちるのではなく、「何がどこで間違っていたか」を全部集めてから返す、という考え方です（保存時の振る舞いは後編の 3-10 でまとめます）。

最初の段の `cast/3` は、外部から来たデータ（attrs）のうち、許可したフィールドだけを取り込む関門です。許可リストに無いキーは黙って捨てられます。これは手間を減らすためだけでなく、`password_hash` のような重要な列を、外部入力で直接書き換えられないようにする意味もあります。

---

## 3-4　Subreddit スキーマ

```elixir
# lib/reddit_clone/communities/subreddit.ex
defmodule RedditClone.Communities.Subreddit do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "subreddits" do
    field :name,        :string
    field :description, :string

    belongs_to :owner, RedditClone.Accounts.User
    has_many :posts,   RedditClone.Posts.Post
    has_many :subreddit_members, RedditClone.Communities.SubredditMember
    has_many :members, through: [:subreddit_members, :user]

    timestamps()
  end

  def changeset(subreddit, attrs) do
    subreddit
    |> cast(attrs, [:name, :description, :owner_id])
    |> validate_required([:name, :owner_id])
    |> validate_length(:name, min: 3, max: 21)
    |> validate_format(:name, ~r/^[a-zA-Z0-9_]+$/)  # r/○○ の部分
    |> validate_length(:description, max: 500)
    |> unique_constraint(:name)
  end
end
```

**読み解き**

`belongs_to :owner, User` は `subreddits.owner_id` が `users.id` を指すことを表します。Ecto は `belongs_to` を見て自動的に `owner_id` カラムとの対応を理解します。

`has_many :members, through: [:subreddit_members, :user]` は中間テーブルを経由した多対多の関係です。直接 `users` テーブルを参照するのではなく、`subreddit_members` を経由して `users` にたどり着きます。読み方は「まず `:subreddit_members`（このスキーマの `has_many`）へ行き、そこから `:user`（SubredditMember 側の `belongs_to`）をたどる」です。第2章で作った中間テーブルが、ここで関係として姿を現します。

`validate_format(:name, ~r/^[a-zA-Z0-9_]+$/)` でコミュニティ名を英数字とアンダースコアのみに制限します。URL の一部になるため、特殊文字を許可しません。

なお、`belongs_to` や `has_many` を書いただけでは、関連データは自動では読み込まれません。取得のときに `preload` という指定をして初めて一緒に読み込まれます（第4章で使います）。宣言は「関係があること」の表明、読み込みは取得時の指定、と分けて覚えてください。

---

## 3-5　SubredditMember スキーマ

```elixir
# lib/reddit_clone/communities/subreddit_member.ex
defmodule RedditClone.Communities.SubredditMember do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_roles ["member", "moderator"]

  schema "subreddit_members" do
    field :role, :string, default: "member"

    belongs_to :user,      RedditClone.Accounts.User
    belongs_to :subreddit, RedditClone.Communities.Subreddit

    timestamps(updated_at: false)
  end

  def changeset(member, attrs) do
    member
    |> cast(attrs, [:user_id, :subreddit_id, :role])
    |> validate_required([:user_id, :subreddit_id])
    |> validate_inclusion(:role, @valid_roles)
    |> unique_constraint([:user_id, :subreddit_id])  # 1人1回のみJoin可能
  end
end
```

**読み解き**

`@valid_roles ["member", "moderator"]` はモジュール属性です。定数として定義しておくことで、後から役割を追加するときに1箇所だけ変更すればよくなります。モジュール属性はコンパイルの時点で値が決まる定数で、実行中に書き換えることはできません。「変わらない値の置き場所」と覚えてください。

`validate_inclusion(:role, @valid_roles)` は `role` が `@valid_roles` のいずれかであることを検証します。予期しない値が入ることを防ぎます。

`unique_constraint([:user_id, :subreddit_id])` はマイグレーションで定義した `unique_index` に対応します。スキーマ側でも宣言することで、DB のエラーを Elixir の `changeset` エラーとして扱えます。

ここは間違えやすい点です。`unique_constraint` 自体は、検証の時点では重複チェックをしません。実際に DB へ保存する瞬間に DB の一意制約で弾かれたら、そのエラーを「どのフィールドのエラーか」に変換する、という役割です。そのため、マイグレーション側の `unique_index` と**対**になっていないと意味がありません。対が無いまま重複を保存しようとすると、変換できない DB エラーがそのまま例外として上がってきます。第2章で `unique_index` を付けた場所と、この章の `unique_constraint` の場所を見比べてみてください。

`timestamps(updated_at: false)` はマイグレーションと揃えます。`updated_at` のないテーブルに対して `updated_at` を持つスキーマを使うとエラーになります。

---

後編では Post・Comment・Vote・Report スキーマを実装します。
