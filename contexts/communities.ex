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
