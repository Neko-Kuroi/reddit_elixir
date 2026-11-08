# 第4章　ビジネスロジック（Context）中編

---

## 4-4　Posts Context

Posts Context はこのアプリで最も複雑なロジックを持ちます。特に投票処理は4つのパターンを正確に処理する必要があります。

```elixir
# lib/reddit_clone/posts.ex
defmodule RedditClone.Posts do
  import Ecto.Query
  alias RedditClone.Repo
  alias RedditClone.Accounts
  alias RedditClone.Posts.Post
  alias RedditClone.Posts.Vote
  alias RedditClone.Comments.Comment

  @page_size 25

  # 投稿を作成する
  def create_post(attrs) do
    %Post{}
    |> Post.changeset(attrs)
    |> Repo.insert()
  end

  # 投稿を1件取得する
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

  # Subreddit の投稿一覧を取得する
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

  # ホーム Feed（Join 済みの投稿一覧）
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

  # ユーザーの投稿一覧（プロフィールページ用）
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

  # キーワードで投稿を検索する
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

  defp apply_sort(query, "hot"), do: order_by(query, [p], desc: p.hot_score)
  defp apply_sort(query, "new"), do: order_by(query, [p], desc: p.inserted_at)
  defp apply_sort(query, _),     do: apply_sort(query, "hot")
end
```

**読み解き**

`list_posts` のクエリで重要な部分を解説します。

```elixir
from(p in Post,
  left_join: c in Comment, on: c.post_id == p.id,  # コメントを結合
  where: p.subreddit_id == ^subreddit_id,
  group_by: p.id,                                   # 投稿ごとに集計
  select_merge: %{comment_count: count(c.id)},      # コメント数を追加
  preload: [:author, :subreddit],
  limit: @page_size,
  offset: ^offset
)
```

`left_join` を使うことでコメントが0件の投稿も結果に含まれます（`inner_join` だとコメントなしの投稿が消えます）。

`select_merge: %{comment_count: count(c.id)}` が `virtual: true` の `comment_count` フィールドに値を入れます。1回のクエリで投稿とコメント数を同時に取得できます。第3章で「DB に列を持たない受け皿」として用意したものが、ここで埋まります。

`preload: [:author, :subreddit]` は、取得した投稿に紐づく著者とコミュニティを、まとめて読み込んでおく指定です。これが無いと、画面で `post.author.username` のように触れたときに「読み込み忘れ」として扱われ、表示のたびに1件ずつ DB へ聞きに行く事態（通称 N+1 問題。件数が増えるほどクエリが増える）や、未読み込みエラー（`Ecto.Association.NotLoaded`）の原因になります。一覧を出すクエリでは「画面で何を表示するか」を見越して preload するのが決まりです。

---

## 4-5　投票ロジック

投票は4つのパターンがあります。

```
パターンA  まだ投票していない        → 新規投票
パターンB  同じ方向に再度押した       → 取り消し
パターンC  逆方向に押した            → 変更
パターンD  自分の投稿に投票しようとした → エラー
```

```elixir
# lib/reddit_clone/posts.ex に追加

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
```

**読み解き**

`process_vote/4` は、第4章の核心である「関数の複数節とパターンマッチ」の実例です。同じ名前の関数が3つ並んでいますが、これは別々の関数ではなく「引数の形によって選ばれる3つの節」です。呼び出されると、節は上から順に試されます。

- 1節目は、第1引数が `nil` のときにだけ合います（まだ投票が無い＝パターンA）
- 2節目は、第1引数の構造体の `value` と第4引数が同じ値のときに合います（パターンB）
- 3節目は、それ以外の投票済みの場合に合います（パターンC）

つまり「どのパターンか」の判定は、`if` や `case` を書かずに、関数の頭の形だけで行われています。入口の `vote_post/3` にある `when value in [1, -1]` はガード（前編で見た追加条件）で、「投票値は 1 か -1 のときだけ受け付ける」という入口の決まりです。

**読み解き（パターンB）**

```elixir
defp process_vote(%Vote{value: same} = vote, post, _user_id, same) do
```

第1引数の `%Vote{value: same}` と第4引数の `same` が**同じ変数名**です。これは Elixir のパターンマッチを使ったトリックです。「既存の投票の `value` が、今回押された `value` と同じとき」にのみこの関数が呼ばれます。同じ変数名が2回現れると「2つが同じ値であること」が条件になる、というのがポイントです。値が違えばこの節には合わず、次の節（パターンC）に進みます。

**読み解き（パターンC）**

```elixir
diff = new_value - old_value
```

`+1` から `-1` に変わった場合、`diff = -1 - 1 = -2` です。スコアを2動かすのは、「Upvote を取り消して Downvote を追加する」という2段階の変化を1回で表現しているためです。

**読み解き（トランザクション）**

```elixir
Repo.transaction(fn ->
  process_vote(...)   # votes の更新 + score の更新 + karma の更新
end)
```

これら3つの操作はセットで成功・失敗しなければなりません。例えば votes の更新は成功したが score の更新が失敗すると、投票は記録されたのにスコアが変わらないという矛盾が生じます。トランザクションがこれを防ぎます。

---

## 4-6　投稿の削除

```elixir
# lib/reddit_clone/posts.ex に追加

def delete_post(post_id, user_id, subreddit) do
  post = get_post!(post_id)
  moderator? = RedditClone.Communities.moderator?(user_id, subreddit.id)

  if post.author_id == user_id || moderator? do
    Repo.delete(post)
  else
    {:error, :unauthorized}
  end
end
```

削除できるのは**本人またはモデレーター**のみです。削除後に Karma は戻しません。Reddit と同じ仕様です。過去の貢献として Karma は残ります。

**読み解き**

ここでは Context 同士の連携も見てください。「モデレーターかどうか」の判定は Posts の中には書かず、`Communities.moderator?/2` を呼んで聞いています。判定のルールの所在は Communities 側で、Posts はその結果を使うだけです。権限が無い場合は例外ではなく `{:error, :unauthorized}` というタプルで返します。呼び出した画面側は、この値を見て「権限がありません」と表示すればよい、という境界の作り方です。

---

後編では Comments Context と Reports Context を実装します。
