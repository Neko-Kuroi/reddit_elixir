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
