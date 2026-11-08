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
