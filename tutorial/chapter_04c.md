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

  # コメントに投票する
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

  # --- ツリー組み立て ---

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

**読み解き**

`build_children` のように、関数が自分自身を呼び出す書き方を**再帰**と呼びます。再帰には必ず「終わりの条件」が必要で、ここでは「子が無い（`Map.get` が既定値の `[]` を返す）」ことがそれにあたります。子が無ければ `Enum.map` は空のリストを返し、それ以上深く潜りません。コメントの返信が何段重なるかは事前に分からないため、「決まった回数の繰り返し」ではなく再帰が向いています。処理の追い方は、「小さい例で1段ずつ追う」のがコツです。上の A〜E の例で、誰が誰を呼ぶかを紙に書いてみてください。

---

## 4-9　Reports Context

```elixir
# lib/reddit_clone/reports.ex
defmodule RedditClone.Reports do
  alias RedditClone.Repo
  alias RedditClone.Reports.Report

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

**読み解き**

`create_report/1` は保存前に2つの確認をします。1つ目は、報告の対象が存在するかどうかです。`get_author_id/2` が `nil` を返した場合（対象がすでに削除されている、不正な ID が送られてきた、など）は、保存せずに `{:error, :target_not_found}` を返します。2つ目は、自分のコンテンツへの報告を防ぐ確認で、対象の作成者と報告者が同じなら `{:error, :cannot_report_own_content}` を返します。`cond` は上から順に条件を見て、最初に当てはまった節を実行する書き方で、このような「確認の順番」が大事な処理に向いています。

`get_author_id/2` は `target_type` によって投稿かコメントかを判断し、作成者の ID を取得します。パターンマッチで2つのケースを別関数として定義しています。

ここでも関数の複数節が使われています。第1引数が文字列 `"post"` そのものなら1節目、`"comment"` なら2節目、という「値そのもの」での振り分けです。そして3節目の `get_author_id(_, _)` は受け皿で、それ以外の `target_type` が来ても落ちずに `nil` を返します。各節の中の `case` は、対象が存在しない場合（`Repo.get` が `nil` を返す場合）に `nil` を返すためのものです。「節で大まかに振り分け、節の中で細かい場合を見る」という二段構えになっています。

なお `create_report/1` の `attrs["target_type"]` という書き方は、文字列キーでマップから値を取る記法です。フォームから届くデータはキーが文字列なので、この章の Context が受け取る `attrs` は文字列キーで統一されています。

---

## 動作確認（この章の仕上げ）

前提: 第2章のマイグレーション実行済み、第3章のスキーマが書けていること。プロジェクトのフォルダで `iex -S mix` を起動して確認します。

- [ ] `RedditClone.Accounts.register_user(%{username: "alice", email: "alice@example.com", password: "password123"})` で `{:ok, %RedditClone.Accounts.User{}}` が返る。同じメールアドレスでもう一度登録すると `{:error, changeset}` になる
- [ ] 登録した alice の ID を使って `RedditClone.Communities.create_subreddit(%{name: "elixir", description: "Elixirの話題", owner_id: alice.id})` を実行すると `{:ok, subreddit}` が返り、`RedditClone.Communities.moderator?(alice.id, subreddit.id)` が `true` になる（作成者がモデレーターとして参加済み）
- [ ] alice が `RedditClone.Posts.create_post(%{title: "はじめての投稿", type: "text", body: "本文", author_id: alice.id, subreddit_id: subreddit.id})` で投稿を作り、別のユーザー bob が `RedditClone.Posts.vote_post(bob.id, post.id, 1)` を実行すると、返ってきた投稿の `score` が `1` になり、alice の `post_karma` も `1` 増えている（`RedditClone.Accounts.get_user!(alice.id)` で確認）
- [ ] bob がもう一度同じ `vote_post(bob.id, post.id, 1)` を実行すると `score` が `0` に戻る（同じ方向の再投票＝取り消し）。続けて `vote_post(bob.id, post.id, -1)` を実行すると `score` が `-1` になる
- [ ] alice が自分の投稿に `RedditClone.Posts.vote_post(alice.id, post.id, 1)` を実行すると `{:error, :cannot_vote_own_post}` が返る
- [ ] 投稿にコメントと、そのコメントへの返信（`parent_id` に親の ID を指定）を作り、`RedditClone.Comments.list_comments(post.id)` を実行すると、返信が親の `replies` の中に入ったツリー構造で返る

---

## よくあるエラーと対処

| 症状 | 原因 | 直し方 |
|------|------|--------|
| 削除の操作で `UndefinedFunctionError`（関数が定義されていない）が出る | 呼び出し側だけが書かれていて、定義側の関数が無い（このアプリでは `Communities.moderator?/2` が実例。削除処理がそれを呼ぶ） | 呼び出している関数が、相手の Context に実在するか確認する。コンパイルが通っても、呼び出し先の欠けは実行時まで分からないことがある |
| 画面で著者名などを読もうとすると `Ecto.Association.NotLoaded` が出る | 取得のときに `preload` し忘れている | 一覧・詳細のクエリに `preload: [:author, :subreddit]` のように、表示に必要な関係を足す |
| 投票の途中で失敗すると、票だけ記録されてスコアが合わない | 複数の更新がトランザクションの外に分かれている | 投票に伴う更新一式を `Repo.transaction` の中に入れる |
| クエリが意図せずエラーになる／条件が効かない | `^`（ピン）を付け忘れて、変数をクエリ内部の名前として解釈させている | 外から来た値をクエリで使う場所には `^` を付ける |
| あるはずのデータで突然クラッシュする | `Repo.get`（無ければ `nil`）と `Repo.get!`（無ければ例外）の使い分けを間違えている | 「無ければエラーでよい」場所は `get!`、「無い場合を処理したい」場所は `get` や `get_by` を使い、戻り値の場合分けをする |

---

## 確認問題

1. Context にルールを集めるのはなぜですか。投票処理を LiveView の側に直接書いた場合、何が困りますか。
2. 既存の投票が `%Vote{value: -1}` の投稿に、同じユーザーがもう一度 `-1` を押しました。`process_vote` のどの節が選ばれ、スコアはどう変わりますか。
3. `vote_post` で自分の投稿に投票しようとした場合、戻り値は何ですか。また、そのときトランザクションは開始されますか。
4. `list_joined_subreddits` のクエリで `join` が果たす役割を説明してください。なぜ `Subreddit` だけの問い合わせでは済まないのですか。
5. `build_tree` に、存在しないコメントを `parent_id` に持つコメントが混ざっていた場合、そのコメントは結果のツリーに現れますか。理由もあわせて答えてください。

---

## まとめと次章へのつながり

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

次の章では、ユーザーの認証システムを実装します。セッションの仕組みと、未ログインユーザーからページを保護する方法を学びます。この章の `Accounts.login_user/2` が、その入口になります。

---

## 確認問題の答え

1. 同じルールが複数の画面で必要になるためです。直接書くと、画面ごとに処理が複製され、ルールが変わったときに直し漏れが出ます。Context に集めれば、直す場所は1か所で、どの画面からも同じ結果になります。
2. 2節目（パターンB）が選ばれます。既存の票の値と新しい値が同じ変数 `same` に束縛されるためです。票は削除され、スコアは `-same`、つまり `+1` されて取り消し前の状態に戻ります。
3. `{:error, :cannot_vote_own_post}` が返ります。トランザクションは開始されません。自分の投稿かどうかの判定は `Repo.transaction` の手前で行われ、エラーはそのまま返るためです。
4. `join` は `subreddit_members`（参加の記録）と `subreddits` を結びつける役割です。「そのユーザーが参加している」という条件は参加の記録の側にしか無いため、Subreddit だけを問い合わせても絞り込めません。
5. 現れません。ツリーは `parent_id` が `nil` のコメントから再帰的にたどって組み立てるため、実在しない親を持つコメントは、どの親の子としてもたどり着けず、結果に入りません。
