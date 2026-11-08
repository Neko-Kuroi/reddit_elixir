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
