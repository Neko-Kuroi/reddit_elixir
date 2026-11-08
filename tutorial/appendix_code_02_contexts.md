# 全コード付録 2　Context 層（ビジネスロジック）

> **このファイルは自動生成です。** 生成スクリプト `~/workspace/reddit_clone_audit/generate_code_appendix.py` が、
> 正本のコードファイル（`~/workspace/reddit_clone_fixed/` 内）から全文を機械的に転記して作りました。
> **正本はコードファイルそのもの**であり、この付録は「すべてのコードがチュートリアル側に収録されている」
> ことを保証するための再録です。コードを直すときは正本を直し、この付録は再生成してください。
>
> 対応する章: 第4章（Context）

---

## contexts/accounts.ex（RedditClone.Accounts）

対応: 第4章。正本: `contexts/accounts.ex`

```elixir
defmodule RedditClone.Accounts do
  @moduledoc """
  アカウント関連のビジネスロジック。
  ユーザー登録・ログイン・取得・Karma更新を担当する。
  """

  import Ecto.Query
  alias RedditClone.Repo
  alias RedditClone.Accounts.User

  # ----------------------------------------------------------------
  # ① ユーザー登録
  # ----------------------------------------------------------------

  @doc """
  新しいユーザーを登録する。

  ## 例
      iex> register_user(%{username: "alice", email: "alice@example.com", password: "password123"})
      {:ok, %User{}}

      iex> register_user(%{username: "", email: "", password: ""})
      {:error, %Ecto.Changeset{}}
  """
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  登録フォームの初期表示用に空のチェンジセットを返す。
  バリデーションは行わない（まだ何も入力されていないため）。

  ## 例
      iex> change_user_registration(%User{})
      %Ecto.Changeset{}
  """
  def change_user_registration(%User{} = user) do
    User.registration_changeset(user, %{})
  end

  # ----------------------------------------------------------------
  # ② ログイン
  # ----------------------------------------------------------------

  @doc """
  emailとpasswordでログインする。
  失敗理由はあえて曖昧にする（セキュリティ上の理由）。

  ## 例
      iex> login_user("alice@example.com", "password123")
      {:ok, %User{}}

      iex> login_user("alice@example.com", "wrongpassword")
      {:error, :invalid_credentials}
  """
  def login_user(email, password) do
    user = Repo.get_by(User, email: email)
    verify_password(user, password)
  end

  # ユーザーが存在してパスワードが一致する場合のみ成功
  defp verify_password(%User{} = user, password) do
    if Bcrypt.verify_pass(password, user.password_hash) do
      {:ok, user}
    else
      {:error, :invalid_credentials}
    end
  end

  # ユーザーが存在しない場合もタイミング攻撃を防ぐためダミーチェックを行う
  defp verify_password(nil, _password) do
    Bcrypt.no_user_verify()
    {:error, :invalid_credentials}
  end

  # ----------------------------------------------------------------
  # ③ ユーザーを1件取得
  # ----------------------------------------------------------------

  @doc """
  usernameでユーザーを取得する（プロフィールページ用）。

  ## 例
      iex> get_user_by_username("alice")
      %User{}

      iex> get_user_by_username("nobody")
      nil
  """
  def get_user_by_username(username) do
    Repo.get_by(User, username: username)
  end

  @doc """
  idでユーザーを取得する。
  存在しない場合はエラーを返す。
  """
  def get_user!(id), do: Repo.get!(User, id)

  # ----------------------------------------------------------------
  # ④ Karmaの更新
  # ----------------------------------------------------------------

  @doc """
  ユーザーのKarmaを増減する。
  投票されたときに Posts / Comments から呼ばれる。

  type は "post" または "comment"。
  amount は +1 または -1。

  ## 例
      iex> update_karma(user_id, "post", 1)
      {:ok, %User{}}

      iex> update_karma(user_id, "comment", -1)
      {:ok, %User{}}
  """
  def update_karma(user_id, type, amount) do
    field = karma_field(type)

    {1, [user]} =
      from(u in User, where: u.id == ^user_id, select: u)
      |> Repo.update_all(inc: [{field, amount}])

    {:ok, user}
  end

  # "post" → :post_karma, "comment" → :comment_karma
  defp karma_field("post"),    do: :post_karma
  defp karma_field("comment"), do: :comment_karma
end
```

## contexts/comments.ex（RedditClone.Comments）

対応: 第4章。正本: `contexts/comments.ex`

```elixir
defmodule RedditClone.Comments do
  @moduledoc """
  コメント関連のビジネスロジック。
  コメントの作成・取得（ネスト）・投票・削除を担当する。
  """

  import Ecto.Query
  alias RedditClone.Repo
  alias RedditClone.Accounts
  alias RedditClone.Comments.Comment
  alias RedditClone.Posts.Vote

  # ----------------------------------------------------------------
  # ① コメントを作る
  # ----------------------------------------------------------------

  @doc """
  コメントを作成する。
  parent_id がある場合は返信、ない場合はトップレベルのコメント。

  ## 例
      iex> create_comment(%{body: "Hello", author_id: id, post_id: id})
      {:ok, %Comment{}}

      iex> create_comment(%{body: "Reply", author_id: id, post_id: id, parent_id: comment_id})
      {:ok, %Comment{}}

      iex> create_comment(%{body: ""})
      {:error, %Ecto.Changeset{}}
  """
  def create_comment(attrs) do
    %Comment{}
    |> Comment.changeset(attrs)
    |> Repo.insert()
  end

  # ----------------------------------------------------------------
  # ② コメントをネスト構造で取得する
  # ----------------------------------------------------------------

  @doc """
  投稿のコメントをツリー構造で取得する。

  DBからフラットなリストで取得し、
  再帰的にツリーへ組み立てて返す。

  ## 例
      iex> list_comments(post_id)
      [
        %Comment{replies: [
          %Comment{replies: []}
        ]},
        %Comment{replies: []}
      ]
  """
  def list_comments(post_id) do
    # 全コメントをフラットに取得（authorも一緒に）
    comments =
      from(c in Comment,
        where: c.post_id == ^post_id,
        preload: [:author],
        order_by: [asc: c.inserted_at]
      )
      |> Repo.all()

    build_tree(comments)
  end

  # フラットなリストをツリーに組み立てる
  defp build_tree(comments) do
    # parent_id ごとにグループ化する
    # %{nil => [A, E], "id-A" => [B, D], "id-B" => [C]}
    by_parent = Enum.group_by(comments, & &1.parent_id)

    # parent_id が nil の子供（ルートノード）から再帰的に組み立てる
    build_children(nil, by_parent)
  end

  # 指定した parent_id を持つ子コメントを再帰的に組み立てる
  defp build_children(parent_id, by_parent) do
    children = Map.get(by_parent, parent_id, [])

    Enum.map(children, fn comment ->
      # 自分の子供を再帰的に取得してrepliesにセットする
      replies = build_children(comment.id, by_parent)
      Map.put(comment, :replies, replies)
    end)
  end

  # ----------------------------------------------------------------
  # ③ コメントに投票する
  # ----------------------------------------------------------------

  @doc """
  コメントに投票する。
  Posts.vote_post と同じ4パターンを処理する。

  パターンA: 新規投票
  パターンB: 同じ方向 → 取り消し
  パターンC: 逆方向   → 変更
  パターンD: 自分のコメント → エラー

  ## 例
      iex> vote_comment(user_id, comment_id, 1)
      {:ok, %Comment{}}

      iex> vote_comment(owner_id, own_comment_id, 1)
      {:error, :cannot_vote_own_comment}
  """
  def vote_comment(user_id, comment_id, value) when value in [1, -1] do
    comment = get_comment!(comment_id)

    if comment.author_id == user_id do
      {:error, :cannot_vote_own_comment}
    else
      existing_vote =
        Repo.get_by(Vote,
          user_id: user_id,
          target_type: "comment",
          target_id: comment_id
        )

      Repo.transaction(fn ->
        process_vote(existing_vote, comment, user_id, value)
      end)
    end
  end

  # パターンA: まだ投票していない → 新規投票
  defp process_vote(nil, comment, user_id, value) do
    %Vote{}
    |> Vote.changeset(%{
      user_id: user_id,
      target_type: "comment",
      target_id: comment.id,
      value: value
    })
    |> Repo.insert!()

    update_scores(comment, value, value)
  end

  # パターンB: 同じ方向に再度投票 → 取り消し
  defp process_vote(%Vote{value: same} = vote, comment, _user_id, same) do
    Repo.delete!(vote)
    update_scores(comment, -same, -same)
  end

  # パターンC: 逆方向に投票 → 変更
  defp process_vote(%Vote{value: old_value} = vote, comment, _user_id, new_value) do
    vote
    |> Vote.changeset(%{value: new_value})
    |> Repo.update!()

    diff = new_value - old_value
    update_scores(comment, diff, diff)
  end

  # score と comment_karma を同時に更新する
  defp update_scores(comment, score_diff, karma_diff) do
    updated_comment =
      comment
      |> Ecto.Changeset.change(score: comment.score + score_diff)
      |> Repo.update!()
      |> Repo.preload([:author])  # 投票後も author を保持する

    # コメント投稿者の comment_karma を更新
    Accounts.update_karma(comment.author_id, "comment", karma_diff)

    updated_comment
  end

  # ----------------------------------------------------------------
  # ④ コメントを削除する
  # ----------------------------------------------------------------

  @doc """
  コメントを削除する。
  本人またはモデレーターのみ削除できる。
  子コメントはDBの on_delete: :delete_all で自動的に削除される。

  ## 例
      iex> delete_comment(comment_id, author_id, subreddit_id)
      {:ok, %Comment{}}

      iex> delete_comment(comment_id, other_user_id, subreddit_id)
      {:error, :unauthorized}

  Note: 削除時に Karma は戻さない。
  Reddit と同様に、過去の投票による Karma は削除後も保持される。
  """
  def delete_comment(comment_id, user_id, subreddit_id) do
    comment = get_comment!(comment_id)
    moderator? = RedditClone.Communities.moderator?(user_id, subreddit_id)

    if comment.author_id == user_id || moderator? do
      Repo.delete(comment)
    else
      {:error, :unauthorized}
    end
  end

  # ----------------------------------------------------------------
  # 内部ヘルパー
  # ----------------------------------------------------------------

  def get_comment!(id), do: Repo.get!(Comment, id)
end
```

## contexts/communities.ex（RedditClone.Communities）

対応: 第4章。正本: `contexts/communities.ex`

```elixir
defmodule RedditClone.Communities do
  @moduledoc """
  コミュニティ関連のビジネスロジック。
  Subredditの作成・取得・参加・脱退を担当する。
  """

  import Ecto.Query
  alias RedditClone.Repo
  alias RedditClone.Communities.Subreddit
  alias RedditClone.Communities.SubredditMember

  # ----------------------------------------------------------------
  # ① Subredditを作る
  # ----------------------------------------------------------------

  @doc """
  Subredditを作成する。
  作成者は自動的にmoderatorとしてJoinされる。
  2つの操作はトランザクションで保護する。

  ## 例
      iex> create_subreddit(%{name: "elixir", description: "Elixirの話題", owner_id: user_id})
      {:ok, %Subreddit{}}

      iex> create_subreddit(%{name: "", owner_id: user_id})
      {:error, %Ecto.Changeset{}}
  """
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

  # ----------------------------------------------------------------
  # ② Subredditを1件取得する
  # ----------------------------------------------------------------

  @doc """
  nameでSubredditを取得する（URLの /r/:name から来る）。

  ## 例
      iex> get_subreddit_by_name("elixir")
      %Subreddit{}

      iex> get_subreddit_by_name("nothing")
      nil
  """
  def get_subreddit_by_name(name) do
    Repo.get_by(Subreddit, name: name)
  end

  @doc """
  idでSubredditを取得する。
  存在しない場合はエラーを返す。
  """
  def get_subreddit!(id), do: Repo.get!(Subreddit, id)

  # ----------------------------------------------------------------
  # ③ Subreddit一覧を取得する
  # ----------------------------------------------------------------

  @doc """
  ユーザーがJoinしているSubreddit一覧を取得する。
  サイドバーやホームFeedで使う。

  ## 例
      iex> list_joined_subreddits(user_id)
      [%Subreddit{}, ...]
  """
  def list_joined_subreddits(user_id) do
    from(s in Subreddit,
      join: m in SubredditMember,
        on: m.subreddit_id == s.id,
      where: m.user_id == ^user_id,
      order_by: [asc: s.name]
    )
    |> Repo.all()
  end

  # ----------------------------------------------------------------
  # ④ Joinする
  # ----------------------------------------------------------------

  @doc """
  ユーザーをSubredditに参加させる。
  すでに参加済みの場合はエラーを返す。

  ## 例
      iex> join_subreddit(user_id, subreddit_id)
      {:ok, %SubredditMember{}}

      iex> join_subreddit(user_id, subreddit_id)  # 2回目
      {:error, %Ecto.Changeset{}}
  """
  def join_subreddit(user_id, subreddit_id) do
    %SubredditMember{}
    |> SubredditMember.changeset(%{
      user_id: user_id,
      subreddit_id: subreddit_id,
      role: "member"
    })
    |> Repo.insert()
  end

  # ----------------------------------------------------------------
  # ⑤ Leaveする
  # ----------------------------------------------------------------

  @doc """
  ユーザーをSubredditから脱退させる。
  オーナーは脱退できない。

  ## 例
      iex> leave_subreddit(user_id, subreddit_id)
      {:ok, %SubredditMember{}}

      iex> leave_subreddit(owner_id, subreddit_id)
      {:error, :owner_cannot_leave}
  """
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

  # ----------------------------------------------------------------
  # ⑥ 参加済みか確認する
  # ----------------------------------------------------------------

  @doc """
  ユーザーがSubredditに参加しているか確認する。
  画面上のJoin/Leaveボタンの表示切替に使う。

  ## 例
      iex> member?(user_id, subreddit_id)
      true

      iex> member?(user_id, other_subreddit_id)
      false
  """
  def member?(user_id, subreddit_id) do
    from(m in SubredditMember,
      where: m.user_id == ^user_id and m.subreddit_id == ^subreddit_id
    )
    |> Repo.exists?()
  end

  # ----------------------------------------------------------------
  # ⑦ モデレーターか確認する
  # ----------------------------------------------------------------

  @doc """
  ユーザーがSubredditのモデレーターかどうかを確認する。
  Posts と Comments の削除権限チェックで使う。

  ## 例
      iex> moderator?(user_id, subreddit_id)
      true

      iex> moderator?(other_user_id, subreddit_id)
      false
  """
  def moderator?(user_id, subreddit_id) do
    from(m in SubredditMember,
      where:
        m.user_id == ^user_id and
          m.subreddit_id == ^subreddit_id and
          m.role == "moderator"
    )
    |> Repo.exists?()
  end

  # ----------------------------------------------------------------
  # ⑧ Subredditを検索する
  # ----------------------------------------------------------------

  @doc """
  名前または説明にキーワードが含まれるSubredditを返す。

  ## 例
      iex> search_subreddits("elixir")
      [%Subreddit{}, ...]
  """
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

## contexts/posts.ex（RedditClone.Posts）

対応: 第4章。正本: `contexts/posts.ex`

```elixir
defmodule RedditClone.Posts do
  @moduledoc """
  投稿関連のビジネスロジック。
  投稿の作成・取得・投票・削除を担当する。
  """

  import Ecto.Query
  alias RedditClone.Repo
  alias RedditClone.Accounts
  alias RedditClone.Posts.Post
  alias RedditClone.Posts.Vote
  alias RedditClone.Comments.Comment

  @page_size 25

  # ----------------------------------------------------------------
  # ① 投稿を作る
  # ----------------------------------------------------------------

  @doc """
  投稿を作成する。
  Hotスコアの初期値はスキーマ側で自動計算される。

  ## 例
      iex> create_post(%{title: "Hello", type: "text", body: "World", author_id: id, subreddit_id: id})
      {:ok, %Post{}}

      iex> create_post(%{title: ""})
      {:error, %Ecto.Changeset{}}
  """
  def create_post(attrs) do
    %Post{}
    |> Post.changeset(attrs)
    |> Repo.insert()
  end

  # ----------------------------------------------------------------
  # ② 投稿を1件取得する
  # ----------------------------------------------------------------

  @doc """
  idで投稿を取得する。
  author と subreddit を一緒に取得する（N+1問題を防ぐ）。

  ## 例
      iex> get_post(post_id)
      %Post{author: %User{}, subreddit: %Subreddit{}}

      iex> get_post("存在しないid")
      nil
  """
  def get_post(id) do
    from(p in Post,
      where: p.id == ^id,
      preload: [:author, :subreddit]
    )
    |> Repo.one()
  end

  def get_post!(id) do
    from(p in Post,
      where: p.id == ^id,
      preload: [:author, :subreddit]
    )
    |> Repo.one!()
  end

  # ----------------------------------------------------------------
  # ③ Subreddit の Feed を取得する
  # ----------------------------------------------------------------

  @doc """
  Subredditの投稿一覧を取得する。
  sort は "hot" または "new"。
  1ページ25件。

  ## 例
      iex> list_posts(subreddit_id, "hot", 1)
      [%Post{}, ...]

      iex> list_posts(subreddit_id, "new", 2)
      [%Post{}, ...]
  """
  def list_posts(subreddit_id, sort \\ "hot", page \\ 1) do
    offset = (page - 1) * @page_size

    from(p in Post,
      left_join: c in Comment, on: c.post_id == p.id,
      where: p.subreddit_id == ^subreddit_id,
      group_by: p.id,
      select_merge: %{comment_count: count(c.id)},
      preload: [:author, :subreddit],
      limit: @page_size,
      offset: ^offset
    )
    |> apply_sort(sort)
    |> Repo.all()
  end

  # ----------------------------------------------------------------
  # ④ ホームFeedを取得する
  # ----------------------------------------------------------------

  @doc """
  ユーザーがJoinしているSubredditの投稿一覧を取得する。
  ログインが必要（HomeFeedLive は require_auth で保護されている）。

  ## 例
      iex> list_home_posts(user_id, "hot", 1)
      [%Post{}, ...]
  """
  def list_home_posts(user_id, sort \\ "hot", page \\ 1) do
    offset = (page - 1) * @page_size

    from(p in Post,
      left_join: c in Comment, on: c.post_id == p.id,
      join: m in RedditClone.Communities.SubredditMember,
        on: m.subreddit_id == p.subreddit_id,
      where: m.user_id == ^user_id,
      group_by: p.id,
      select_merge: %{comment_count: count(c.id)},
      preload: [:author, :subreddit],
      limit: @page_size,
      offset: ^offset
    )
    |> apply_sort(sort)
    |> Repo.all()
  end

  # ソートの適用（hot / new）
  defp apply_sort(query, "hot"), do: order_by(query, [p], desc: p.hot_score)
  defp apply_sort(query, "new"), do: order_by(query, [p], desc: p.inserted_at)
  defp apply_sort(query, _),     do: apply_sort(query, "hot")

  # ----------------------------------------------------------------
  # ⑤ ユーザーの投稿一覧を取得する（プロフィールページ用）
  # ----------------------------------------------------------------

  @doc """
  指定ユーザーの投稿一覧を新着順で取得する。

  ## 例
      iex> list_user_posts(user_id, 1)
      [%Post{}, ...]
  """
  def list_user_posts(user_id, page \\ 1) do
    offset = (page - 1) * @page_size

    from(p in Post,
      left_join: c in Comment, on: c.post_id == p.id,
      where: p.author_id == ^user_id,
      group_by: p.id,
      select_merge: %{comment_count: count(c.id)},
      preload: [:author, :subreddit],
      order_by: [desc: p.inserted_at],
      limit: @page_size,
      offset: ^offset
    )
    |> Repo.all()
  end

  # ----------------------------------------------------------------
  # ⑤ 投票する
  # ----------------------------------------------------------------

  @doc """
  投稿に投票する。
  4つのパターンを処理する。

  パターンA: 新規投票
  パターンB: 同じ方向 → 取り消し
  パターンC: 逆方向   → 変更
  パターンD: 自分の投稿 → エラー

  ## 例
      iex> vote_post(user_id, post_id, 1)
      {:ok, %Post{}}

      iex> vote_post(owner_id, own_post_id, 1)
      {:error, :cannot_vote_own_post}
  """
  def vote_post(user_id, post_id, value) when value in [1, -1] do
    post = get_post!(post_id)

    if post.author_id == user_id do
      # パターンD: 自分の投稿には投票できない
      {:error, :cannot_vote_own_post}
    else
      existing_vote =
        Repo.get_by(Vote,
          user_id: user_id,
          target_type: "post",
          target_id: post_id
        )

      Repo.transaction(fn ->
        process_vote(existing_vote, post, user_id, value)
      end)
    end
  end

  # パターンA: まだ投票していない → 新規投票
  defp process_vote(nil, post, user_id, value) do
    %Vote{}
    |> Vote.changeset(%{
      user_id: user_id,
      target_type: "post",
      target_id: post.id,
      value: value
    })
    |> Repo.insert!()

    update_scores(post, value, value)
  end

  # パターンB: 同じ方向に再度投票 → 取り消し
  defp process_vote(%Vote{value: same} = vote, post, _user_id, same) do
    Repo.delete!(vote)
    update_scores(post, -same, -same)
  end

  # パターンC: 逆方向に投票 → 変更
  defp process_vote(%Vote{value: old_value} = vote, post, _user_id, new_value) do
    vote
    |> Vote.changeset(%{value: new_value})
    |> Repo.update!()

    # 例: +1 → -1 の場合、差分は -2
    diff = new_value - old_value
    update_scores(post, diff, diff)
  end

  # score と hot_score と karma を同時に更新する
  defp update_scores(post, score_diff, karma_diff) do
    new_score = post.score + score_diff
    new_hot   = Post.compute_hot_score(new_score, post.inserted_at)

    updated_post =
      post
      |> Ecto.Changeset.change(score: new_score, hot_score: new_hot)
      |> Repo.update!()
      |> Repo.preload([:author, :subreddit])  # 投票後も author/subreddit を保持する

    # 投稿者のKarmaも更新
    Accounts.update_karma(post.author_id, "post", karma_diff)

    updated_post
  end

  # ----------------------------------------------------------------
  # ⑥ 投稿を検索する
  # ----------------------------------------------------------------

  @doc """
  タイトルにキーワードが含まれる投稿を返す。
  大文字小文字を無視した部分一致検索。

  ## 例
      iex> search_posts("elixir")
      [%Post{}, ...]
  """
  def search_posts(query) when is_binary(query) and query != "" do
    term = "%#{query}%"

    from(p in Post,
      left_join: c in Comment, on: c.post_id == p.id,
      where: ilike(p.title, ^term),
      group_by: p.id,
      select_merge: %{comment_count: count(c.id)},
      preload: [:author, :subreddit],
      order_by: [desc: p.hot_score],
      limit: 25
    )
    |> Repo.all()
  end

  def search_posts(_), do: []

  # ----------------------------------------------------------------
  # ⑦ 投稿を削除する
  # ----------------------------------------------------------------

  @doc """
  投稿を削除する。
  本人またはモデレーターのみ削除できる。

  Note: 削除時に Karma は戻さない。
  Reddit と同様に、過去の投票による Karma は削除後も保持される。

  ## 例
      iex> delete_post(post_id, author_id, subreddit)
      {:ok, %Post{}}

      iex> delete_post(post_id, other_user_id, subreddit)
      {:error, :unauthorized}
  """
  def delete_post(post_id, user_id, subreddit) do
    post = get_post!(post_id)
    moderator? = RedditClone.Communities.moderator?(user_id, subreddit.id)

    if post.author_id == user_id || moderator? do
      Repo.delete(post)
    else
      {:error, :unauthorized}
    end
  end
end
```

## contexts/reports.ex（RedditClone.Reports）

対応: 第4章。正本: `contexts/reports.ex`

```elixir
defmodule RedditClone.Reports do
  @moduledoc """
  報告関連のビジネスロジック。
  投稿・コメントへの報告を担当する。
  """

  alias RedditClone.Repo
  alias RedditClone.Reports.Report

  # ----------------------------------------------------------------
  # ① 報告を作成する
  # ----------------------------------------------------------------

  @doc """
  投稿またはコメントを報告する。
  自分のコンテンツは報告できない。
  対象が存在しない場合は `{:error, :target_not_found}` を返す。

  ## 例
      iex> create_report(%{
      ...>   reporter_id: user_id,
      ...>   target_type: "post",
      ...>   target_id: post_id,
      ...>   reason: "spam"
      ...> })
      {:ok, %Report{}}

      iex> create_report(%{reporter_id: author_id, target_id: own_post_id, ...})
      {:error, :cannot_report_own_content}
  """
  def create_report(attrs) do
    target_author_id = get_author_id(attrs["target_type"], attrs["target_id"])

    cond do
      # 対象が存在しない（削除済み・不正な ID など）場合は報告を受け付けない
      is_nil(target_author_id) ->
        {:error, :target_not_found}

      target_author_id == attrs["reporter_id"] ->
        {:error, :cannot_report_own_content}

      true ->
        %Report{}
        |> Report.changeset(attrs)
        |> Repo.insert()
    end
  end

  # 投稿またはコメントの author_id を取得する
  defp get_author_id("post", target_id) do
    case Repo.get(RedditClone.Posts.Post, target_id) do
      nil  -> nil
      post -> post.author_id
    end
  end

  defp get_author_id("comment", target_id) do
    case Repo.get(RedditClone.Comments.Comment, target_id) do
      nil     -> nil
      comment -> comment.author_id
    end
  end

  defp get_author_id(_, _), do: nil
end
```
