# 第4章　ビジネスロジック（Context）後編

---

## 4-7　Comments Context

```elixir
# lib/reddit_clone/comments.ex
defmodule RedditClone.Comments do
  import Ecto.Query
  alias RedditClone.Repo
  alias RedditClone.Accounts
  alias RedditClone.Comments.Comment
  alias RedditClone.Posts.Vote

  # コメントを作成する
  def create_comment(attrs) do
    %Comment{}
    |> Comment.changeset(attrs)
    |> Repo.insert()
  end

  # 投稿のコメントをツリー構造で取得する
  def list_comments(post_id) do
    comments =
      from(c in Comment,
        where: c.post_id == ^post_id,
        preload: [:author],
        order_by: [asc: c.inserted_at]
      )
      |> Repo.all()

    build_tree(comments)
  end

  # コメントに投票する
  def vote_comment(user_id, comment_id, value) when value in [1, -1] do
    comment = get_comment!(comment_id)

    if comment.author_id == user_id do
      {:error, :cannot_vote_own_comment}
    else
      existing_vote = Repo.get_by(Vote,
        user_id: user_id,
        target_type: "comment",
        target_id: comment_id
      )

      Repo.transaction(fn ->
        process_vote(existing_vote, comment, user_id, value)
      end)
    end
  end

  # コメントを削除する（本人またはモデレーターのみ）
  def delete_comment(comment_id, user_id, subreddit_id) do
    comment = get_comment!(comment_id)
    moderator? = RedditClone.Communities.moderator?(user_id, subreddit_id)

    if comment.author_id == user_id || moderator? do
      Repo.delete(comment)
    else
      {:error, :unauthorized}
    end
  end

  def get_comment!(id), do: Repo.get!(Comment, id)

  # --- 投票の内部処理 ---

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

  defp process_vote(%Vote{value: same} = vote, comment, _user_id, same) do
    Repo.delete!(vote)
    update_scores(comment, -same, -same)
  end

  defp process_vote(%Vote{value: old_value} = vote, comment, _user_id, new_value) do
    vote |> Vote.changeset(%{value: new_value}) |> Repo.update!()
    diff = new_value - old_value
    update_scores(comment, diff, diff)
  end

  defp update_scores(comment, score_diff, karma_diff) do
    updated_comment =
      comment
      |> Ecto.Changeset.change(score: comment.score + score_diff)
      |> Repo.update!()
      |> Repo.preload([:author])

    Accounts.update_karma(comment.author_id, "comment", karma_diff)
    updated_comment
  end

  # --- ツリー組み立て ---

  defp build_tree(comments) do
    by_parent = Enum.group_by(comments, & &1.parent_id)
    build_children(nil, by_parent)
  end

  defp build_children(parent_id, by_parent) do
    children = Map.get(by_parent, parent_id, [])

    Enum.map(children, fn comment ->
      replies = build_children(comment.id, by_parent)
      Map.put(comment, :replies, replies)
    end)
  end
end
```

---

## 4-8　ツリー組み立てのアルゴリズム

コメントのツリー組み立ては少し難しいので丁寧に説明します。

DB から取得したコメントはフラットなリストです。

```
[
  %Comment{id: "A", parent_id: nil,  body: "最初のコメント"},
  %Comment{id: "B", parent_id: "A",  body: "Aへの返信"},
  %Comment{id: "C", parent_id: "B",  body: "Bへの返信"},
  %Comment{id: "D", parent_id: "A",  body: "Aへの別の返信"},
  %Comment{id: "E", parent_id: nil,  body: "2番目のコメント"}
]
```

これをツリー構造に変換します。

**Step 1: `group_by` で parent_id ごとにグループ化する**

```elixir
by_parent = Enum.group_by(comments, & &1.parent_id)
```

結果は以下のマップになります。

```elixir
%{
  nil => [A, E],   # トップレベル
  "A" => [B, D],   # A の子
  "B" => [C]       # B の子
}
```

**Step 2: `build_children` で再帰的にツリーを組み立てる**

```elixir
defp build_children(parent_id, by_parent) do
  children = Map.get(by_parent, parent_id, [])  # この parent_id の子を取得

  Enum.map(children, fn comment ->
    replies = build_children(comment.id, by_parent)  # 再帰！
    Map.put(comment, :replies, replies)
  end)
end
```

`build_children(nil, ...)` から始めると、トップレベルのコメント A と E が取得されます。

A の子を取得するために `build_children("A", ...)` が呼ばれ、B と D が返ります。

B の子を取得するために `build_children("B", ...)` が呼ばれ、C が返ります。

C の子を取得するために `build_children("C", ...)` が呼ばれますが、マップにキー `"C"` がないので `[]` が返ります。ここで再帰が終わります。

**結果**

```
A
  replies: [
    B
      replies: [C]
    D
      replies: []
  ]
E
  replies: []
```

この設計のポイントは1回の DB クエリで全コメントを取得してから、メモリ上でツリーを組み立てることです。コメントの深さに関わらず DB へのアクセスは1回だけです。

---

## 4-9　Reports Context

```elixir
# lib/reddit_clone/reports.ex
defmodule RedditClone.Reports do
  alias RedditClone.Repo
  alias RedditClone.Reports.Report

  def create_report(attrs) do
    target_author_id = get_author_id(attrs["target_type"], attrs["target_id"])

    if target_author_id == attrs["reporter_id"] do
      {:error, :cannot_report_own_content}
    else
      %Report{}
      |> Report.changeset(attrs)
      |> Repo.insert()
    end
  end

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

**解説**

`create_report/1` は保存前に自分のコンテンツへの報告を防ぎます。

`get_author_id/2` は `target_type` によって投稿かコメントかを判断し、作成者の ID を取得します。パターンマッチで2つのケースを別関数として定義しています。

---

## まとめ

この章では以下を完了しました。

```
✅ Context パターンの目的と設計を理解した
✅ Accounts Context（登録・ログイン・Karma）
✅ Communities Context（Subreddit・参加・脱退）
✅ Posts Context（投稿・投票・検索）
✅ Comments Context（コメント・ツリー構造）
✅ Reports Context（報告）
```

**この章の重要なポイント**

- タイミング攻撃対策として `Bcrypt.no_user_verify()` を使う
- トランザクションで複数操作の整合性を保つ
- `Repo.update_all(inc: ...)` で競合なく Karma を更新する
- コメントツリーは1回のクエリで取得して `group_by` + 再帰で組み立てる
- 投票は4パターンをパターンマッチで分岐する

次の章では、ユーザーの認証システムを実装します。セッションの仕組みと、未ログインユーザーからページを保護する方法を学びます。
