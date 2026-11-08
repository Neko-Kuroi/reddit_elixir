# 第4章　ビジネスロジック（Context）前編

---

## 4-1　Context パターンとは

Context とは**アプリのルールをまとめたモジュール**です。

例えば「投票する」という操作を考えます。ボタンを1回押すだけに見えますが、裏側では複数の処理が必要です。

```
① このユーザーはすでに投票していないか確認する
② 自分の投稿には投票できない
③ votes テーブルに記録する
④ posts.score を更新する
⑤ 投稿者の post_karma を更新する
⑥ hot_score を再計算する
```

これらを画面（LiveView）に直接書くと、別の画面でも同じ処理が必要になったとき、コードをコピーすることになります。ルールが変わったとき全箇所を修正しなければなりません。

Context を使うと、ルールを1箇所に集めて管理できます。

```
画面（LiveView）
  └─ 「投票して」と Context に依頼するだけ

Context（Posts）
  └─ ルールに従って処理する ← ここにロジックが集まる

DB（PostgreSQL）
  └─ データを保存するだけ
```

---

### Context のファイル構成

```
lib/reddit_clone/
  ├─ accounts.ex       ← Accounts Context
  ├─ communities.ex    ← Communities Context
  ├─ posts.ex          ← Posts Context
  ├─ comments.ex       ← Comments Context
  └─ reports.ex        ← Reports Context
```

---

## 4-2　Accounts Context

```elixir
# lib/reddit_clone/accounts.ex
defmodule RedditClone.Accounts do
  import Ecto.Query
  alias RedditClone.Repo
  alias RedditClone.Accounts.User

  # ユーザー登録フォームの初期表示用（空のチェンジセット）
  def change_user_registration(%User{} = user) do
    User.registration_changeset(user, %{})
  end

  # ユーザーを登録する
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  # ログインする
  def login_user(email, password) do
    user = Repo.get_by(User, email: email)
    verify_password(user, password)
  end

  # username でユーザーを取得する（プロフィールページ用）
  def get_user_by_username(username) do
    Repo.get_by(User, username: username)
  end

  def get_user!(id), do: Repo.get!(User, id)

  # Karma を増減する（投票されたときに呼ばれる）
  def update_karma(user_id, type, amount) do
    field = karma_field(type)

    {1, [user]} =
      from(u in User, where: u.id == ^user_id, select: u)
      |> Repo.update_all(inc: [{field, amount}])

    {:ok, user}
  end

  defp verify_password(%User{} = user, password) do
    if Bcrypt.verify_pass(password, user.password_hash) do
      {:ok, user}
    else
      {:error, :invalid_credentials}
    end
  end

  defp verify_password(nil, _password) do
    Bcrypt.no_user_verify()
    {:error, :invalid_credentials}
  end

  defp karma_field("post"),    do: :post_karma
  defp karma_field("comment"), do: :comment_karma
end
```

**解説**

`login_user/2` の実装に注目してください。

```elixir
defp verify_password(nil, _password) do
  Bcrypt.no_user_verify()   # ← ダミーのハッシュ計算を行う
  {:error, :invalid_credentials}
end
```

ユーザーが存在しない場合でも `Bcrypt.no_user_verify()` を呼びます。これは**タイミング攻撃**への対策です。

ユーザーが存在しないとき処理が即座に返ってくれば、攻撃者は「このメールアドレスは登録されていない」と判断できます。ダミーのハッシュ計算を行うことで処理時間を同じにし、ユーザーの存在有無を推測できなくします。

また失敗メッセージは「メールが違います」「パスワードが違います」と分けません。`{:error, :invalid_credentials}` のみを返します。どちらが間違っているかを教えると、攻撃者の手がかりになるためです。

`update_karma/3` は `Repo.update_all` を使って直接 DB で値を増減します。

```elixir
Repo.update_all(inc: [{field, amount}])
```

「取得して +1 して保存」ではなく、DB レベルで `UPDATE users SET post_karma = post_karma + 1` を実行します。複数の投票が同時に来ても Karma がずれません。

---

## 4-3　Communities Context

```elixir
# lib/reddit_clone/communities.ex
defmodule RedditClone.Communities do
  import Ecto.Query
  alias RedditClone.Repo
  alias RedditClone.Communities.Subreddit
  alias RedditClone.Communities.SubredditMember

  # Subreddit を作成する（作成者を moderator として登録）
  def create_subreddit(attrs) do
    Repo.transaction(fn ->
      subreddit =
        %Subreddit{}
        |> Subreddit.changeset(attrs)
        |> Repo.insert!()

      %SubredditMember{}
      |> SubredditMember.changeset(%{
        user_id: subreddit.owner_id,
        subreddit_id: subreddit.id,
        role: "moderator"
      })
      |> Repo.insert!()

      subreddit
    end)
  end

  def get_subreddit_by_name(name) do
    Repo.get_by(Subreddit, name: name)
  end

  def get_subreddit!(id), do: Repo.get!(Subreddit, id)

  # Join 済みの Subreddit 一覧（サイドバー用）
  def list_joined_subreddits(user_id) do
    from(s in Subreddit,
      join: m in SubredditMember, on: m.subreddit_id == s.id,
      where: m.user_id == ^user_id,
      order_by: [asc: s.name]
    )
    |> Repo.all()
  end

  # Subreddit に参加する
  def join_subreddit(user_id, subreddit_id) do
    %SubredditMember{}
    |> SubredditMember.changeset(%{
      user_id: user_id,
      subreddit_id: subreddit_id,
      role: "member"
    })
    |> Repo.insert()
  end

  # Subreddit から脱退する（オーナーは不可）
  def leave_subreddit(user_id, subreddit_id) do
    subreddit = get_subreddit!(subreddit_id)

    if subreddit.owner_id == user_id do
      {:error, :owner_cannot_leave}
    else
      member = Repo.get_by!(SubredditMember,
        user_id: user_id,
        subreddit_id: subreddit_id
      )
      Repo.delete(member)
    end
  end

  # 参加済みかどうかを確認する
  def member?(user_id, subreddit_id) do
    from(m in SubredditMember,
      where: m.user_id == ^user_id and m.subreddit_id == ^subreddit_id
    )
    |> Repo.exists?()
  end

  # モデレーターかどうかを確認する
  def moderator?(user_id, subreddit_id) do
    from(m in SubredditMember,
      where:
        m.user_id == ^user_id and
        m.subreddit_id == ^subreddit_id and
        m.role == "moderator"
    )
    |> Repo.exists?()
  end

  # キーワードで Subreddit を検索する
  def search_subreddits(query) when is_binary(query) and query != "" do
    term = "%#{query}%"
    from(s in Subreddit,
      where: ilike(s.name, ^term) or ilike(s.description, ^term),
      order_by: [asc: s.name],
      limit: 10
    )
    |> Repo.all()
  end
  def search_subreddits(_), do: []
end
```

**解説**

`create_subreddit/1` は `Repo.transaction/1` でトランザクションを使います。

```elixir
Repo.transaction(fn ->
  subreddit = Repo.insert!(...)   # Subreddit を保存
  Repo.insert!(...)               # Moderator として登録
  subreddit
end)
```

2つの操作をトランザクションで包むことで「Subreddit は作成されたが Moderator の登録は失敗した」という中途半端な状態を防ぎます。どちらかが失敗すると両方がロールバックされます。

`member?/2` と `moderator?/2` は `Repo.exists?()` を使います。レコード全体を取得せず、存在確認だけを行うため効率的です。

`search_subreddits/1` の `ilike` は大文字小文字を無視した部分一致検索です。`"Elixir"` で検索しても `"elixir"` がヒットします。

---

次の後編では Posts Context の投票ロジックを詳しく説明します。
