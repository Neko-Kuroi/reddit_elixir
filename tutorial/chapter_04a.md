# 第4章　ビジネスロジック（Context）前編

---

### この章で学ぶこと

- 作るもの: 5つの Context（Accounts、Communities、Posts、Comments、Reports）。前編では Accounts と Communities、中編では Posts、後編では Comments と Reports を扱います
- 学ぶ考え方: Context パターン、Ecto のクエリの組み立て方、関数の複数節とパターンマッチ、トランザクション、再帰によるツリー組み立て、`{:ok, _}` / `{:error, _}` の戻り値の約束

### 前提

- 第3章が済んでいること（7つのスキーマとチェンジセットが書けていること）
- 第2章のマイグレーションが実行済みで、テーブルが存在すること

### 全体の中での位置

この章は3層構造の真ん中、Context 層を作る章です。第3章のスキーマ（Data 層）を使って「アプリのルール」を実装し、第6章の画面（Web 層）はここで作る関数を呼ぶだけになります。ルールを置く場所をここ1か所に決めるのが、この章いちばんの目的です。

> この章のコードについて: 実ファイルの各関数には `@doc`（関数の説明文）が付いています。本文では関数の本体に集中するため `@doc` は省略しています。`@doc` を含む全文は、全コード付録2（appendix_code_02_contexts.md）に収録しています。

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

**読み解き**

Context の見方をもう1つ加えます。Context の公開関数（`def` で書かれた関数）の一覧が、そのまま「このアプリにできる操作」の一覧になります。画面側は、内部でどんなテーブルをどう触るかを知らなくてよく、「どの Context の、どの関数を呼ぶか」だけを知っていれば済みます。この「表に見える関数の集まりが境界になる」という考え方が Context パターンです。第3章で学んだ `{:ok, _}` / `{:error, _}` のタプルも、この境界を越える戻り値の約束として使われます。

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

**読み解き**

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

もう1つ、この Context のコード全体に通じる書き方を押さえます。**関数の複数節とパターンマッチ**です。

`verify_password/2` は2つの節（同じ名前の関数定義）からできています。第1引数が `%User{}` の形なら1節目、`nil` なら2節目が選ばれます。呼び出し側は「ユーザーがいるかどうか」を `if` で分岐しません。受け取る値の形そのものが振り分けになる、というのがパターンマッチの発想です。節は上から順に試され、当てはまった最初の節が実行されます。

末尾の `karma_field/1` も同じ発想で、文字列 `"post"` と `"comment"` という値そのもので振り分けています。条件分岐を関数の頭に書くことで、本体は「その場合にやること」だけに集中できます。この書き方は中編の投票処理（`process_vote`）で本格的に使います。

`update_karma/3` の中の `{1, [user]} =` という行もパターンマッチです。`Repo.update_all` は「更新した件数と、更新された行のリスト」というタプルを返すので、それをこの形で受けて `user` を取り出しています。「件数は必ず1件のはず」という前提を形で表明しているので、もし0件だった場合はその場でエラー（MatchError）になり、静かに間違いが進むのを防ぎます。

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
      # Subredditを保存
      subreddit =
        %Subreddit{}
        |> Subreddit.changeset(attrs)
        |> Repo.insert!()

      # 作成者をmoderatorとして登録
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
      join: m in SubredditMember,
        on: m.subreddit_id == s.id,
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
      # オーナーは脱退できない
      {:error, :owner_cannot_leave}
    else
      member =
        Repo.get_by!(SubredditMember,
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

**読み解き**

`create_subreddit/1` は `Repo.transaction/1` でトランザクションを使います。トランザクションとは「複数の DB 操作をひとまとまりとして扱い、全部成功するか、全部無かったことにする」仕組みです。

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

クエリの組み立て方についても、ここでまとめておきます。この章の `from(...)` という書き方は、その場で DB に問い合わせるのではなく、まず「クエリ（問い合わせの内容を表す構造体）」を組み立てるだけです。実際に DB へ実行されるのは、組み上がったクエリが `Repo.all()`（一覧で取得）、`Repo.one()`（1件だけ取得）、`Repo.exists?()`（有無だけ確認）などに渡された瞬間です。「組み立てる」と「実行する」が分かれているので、`from` の結果を変数に入れて、条件によって付け足す、といった組み立てもできます。

`where: m.user_id == ^user_id` の `^` は**ピン演算子**と呼びます。クエリの中で Elixir 側の変数の値を使うときの印で、「この場所には `user_id` の値を埋め込む」という意味です。クエリの中は通常の Elixir のコードとは少し違う世界で、列名（`m.user_id`）と外から来た値を区別するためにこの印が必要になります。付け忘れると、意図しない解釈をされてエラーになります。

`search_subreddits/1` の1節目にある `when is_binary(query) and query != ""` は**ガード**と呼び、「引数が空でない文字列のときにだけ、この節を使う」という追加の条件です。条件に当てはまらない入力は、2節目の `search_subreddits(_)` が受け止めて `[]` を返します。`_` は「値は何でもよいし、使わない」という意味の印です。複数節とガードを組み合わせると、「想定した入力は本体で処理し、それ以外は入口で穏やかに返す」という形が作れます。

---

次の後編では Posts Context の投票ロジックを詳しく説明します。
