# 第3章　Ecto スキーマ（前編）

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
    field :password,      :string, virtual: true  # DB に保存しない
    field :post_karma,    :integer, default: 0
    field :comment_karma, :integer, default: 0

    has_many :posts,    RedditClone.Posts.Post,      foreign_key: :author_id
    has_many :comments, RedditClone.Comments.Comment, foreign_key: :author_id
    has_many :subreddit_members, RedditClone.Communities.SubredditMember
    has_many :subreddits, through: [:subreddit_members, :subreddit]

    timestamps()
  end

  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :email, :password])
    |> validate_required([:username, :email, :password])
    |> validate_length(:username, min: 3, max: 20)
    |> validate_format(:username, ~r/^[a-zA-Z0-9_]+$/)
    |> validate_format(:email, ~r/@/)
    |> validate_length(:password, min: 8)
    |> unique_constraint(:username)
    |> unique_constraint(:email)
    |> put_password_hash()
  end

  defp put_password_hash(changeset) do
    case get_change(changeset, :password) do
      nil      -> changeset
      password -> put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))
    end
  end
end
```

**解説**

`@primary_key {:id, :binary_id, autogenerate: true}` はマイグレーションで UUID を使ったことに対応する設定です。全スキーマに必要です。

`field :password, :string, virtual: true` の `virtual: true` は重要です。このフィールドはユーザーが入力したパスワードを一時的に保持するためのものです。DB には保存されません。代わりに `put_password_hash/1` がハッシュ化して `password_hash` に入れます。

`validate_format(:username, ~r/^[a-zA-Z0-9_]+$/)` は正規表現でユーザー名の形式を検証します。英数字とアンダースコアのみを許可します。

`get_change(changeset, :password)` は「パスワードが変更されたか」を確認します。`nil` のとき（変更なし）はハッシュ化をスキップします。

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
    |> validate_format(:name, ~r/^[a-zA-Z0-9_]+$/)
    |> validate_length(:description, max: 500)
    |> unique_constraint(:name)
  end
end
```

**解説**

`belongs_to :owner, User` は `subreddits.owner_id` が `users.id` を指すことを表します。Ecto は `belongs_to` を見て自動的に `owner_id` カラムとの対応を理解します。

`has_many :members, through: [:subreddit_members, :user]` は中間テーブルを経由した多対多の関係です。直接 `users` テーブルを参照するのではなく、`subreddit_members` を経由して `users` にたどり着きます。

`validate_format(:name, ~r/^[a-zA-Z0-9_]+$/)` でコミュニティ名を英数字とアンダースコアのみに制限します。URL の一部になるため、特殊文字を許可しません。

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
    |> unique_constraint([:user_id, :subreddit_id])
  end
end
```

**解説**

`@valid_roles ["member", "moderator"]` はモジュール属性です。定数として定義しておくことで、後から役割を追加するときに1箇所だけ変更すればよくなります。

`validate_inclusion(:role, @valid_roles)` は `role` が `@valid_roles` のいずれかであることを検証します。予期しない値が入ることを防ぎます。

`unique_constraint([:user_id, :subreddit_id])` はマイグレーションで定義した `unique_index` に対応します。スキーマ側でも宣言することで、DB のエラーを Elixir の `changeset` エラーとして扱えます。

`timestamps(updated_at: false)` はマイグレーションと揃えます。`updated_at` のないテーブルに対して `updated_at` を持つスキーマを使うとエラーになります。

---

後編では Post・Comment・Vote・Report スキーマを実装します。
