# 全コード付録 1　データ層（マイグレーション＋スキーマ）

> **このファイルは自動生成です。** 生成スクリプト `~/workspace/reddit_clone_audit/generate_code_appendix.py` が、
> 正本のコードファイル（`~/workspace/reddit_clone_fixed/` 内）から全文を機械的に転記して作りました。
> **正本はコードファイルそのもの**であり、この付録は「すべてのコードがチュートリアル側に収録されている」
> ことを保証するための再録です。コードを直すときは正本を直し、この付録は再生成してください。
>
> 対応する章: 第2章（マイグレーション）、第3章（スキーマ）

---

## migrations/20240001000000_create_users.exs（RedditClone.Repo.Migrations.CreateUsers）

対応: 第2章。正本: `migrations/20240001000000_create_users.exs`

```elixir
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

## migrations/20240001000001_create_subreddits.exs（RedditClone.Repo.Migrations.CreateSubreddits）

対応: 第2章。正本: `migrations/20240001000001_create_subreddits.exs`

```elixir
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

## migrations/20240001000002_create_subreddit_members.exs（RedditClone.Repo.Migrations.CreateSubredditMembers）

対応: 第2章。正本: `migrations/20240001000002_create_subreddit_members.exs`

```elixir
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

## migrations/20240001000003_create_posts.exs（RedditClone.Repo.Migrations.CreatePosts）

対応: 第2章。正本: `migrations/20240001000003_create_posts.exs`

```elixir
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

## migrations/20240001000004_create_comments.exs（RedditClone.Repo.Migrations.CreateComments）

対応: 第2章。正本: `migrations/20240001000004_create_comments.exs`

```elixir
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

## migrations/20240001000005_create_votes.exs（RedditClone.Repo.Migrations.CreateVotes）

対応: 第2章。正本: `migrations/20240001000005_create_votes.exs`

```elixir
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

## migrations/20240001000006_create_reports.exs（RedditClone.Repo.Migrations.CreateReports）

対応: 第2章。正本: `migrations/20240001000006_create_reports.exs`

```elixir
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

## schemas/comment.ex（RedditClone.Comments.Comment）

対応: 第3章。正本: `schemas/comment.ex`

```elixir
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

## schemas/post.ex（RedditClone.Posts.Post）

対応: 第3章。正本: `schemas/post.ex`

```elixir
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

## schemas/report.ex（RedditClone.Reports.Report）

対応: 第3章。正本: `schemas/report.ex`

```elixir
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

## schemas/subreddit.ex（RedditClone.Communities.Subreddit）

対応: 第3章。正本: `schemas/subreddit.ex`

```elixir
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

## schemas/subreddit_member.ex（RedditClone.Communities.SubredditMember）

対応: 第3章。正本: `schemas/subreddit_member.ex`

```elixir
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

## schemas/user.ex（RedditClone.Accounts.User）

対応: 第3章。正本: `schemas/user.ex`

```elixir
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

## schemas/vote.ex（RedditClone.Posts.Vote）

対応: 第3章。正本: `schemas/vote.ex`

```elixir
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
