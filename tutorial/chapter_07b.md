# 第7章　コンポーネント（後編）

---

## 7-4　CommentTree（再帰コンポーネント）

CommentTree はコメントをネスト構造で表示する再帰コンポーネントです。

```elixir
# lib/reddit_clone_web/live/components/comment_tree.ex
defmodule RedditCloneWeb.Components.CommentTree do
  @moduledoc """
  コメントをネスト構造で再帰的に表示するコンポーネント。
  PostLive から使う。
  """

  use RedditCloneWeb, :html

  import RedditCloneWeb.Helpers

  @max_depth 8

  @doc """
  コメントツリーを表示する。

  ## 属性
    - comments:     表示するコメントのリスト（ツリー構造）
    - current_user: ログイン中のユーザー（nil可）
    - depth:        現在のネスト深さ（デフォルト0）
  """
  attr :comments,     :list,  required: true
  attr :current_user, :map,   default: nil
  attr :depth,        :integer, default: 0

  def comment_tree(assigns) do
    ~H"""
    <div class={depth_class(@depth)}>
      <%= for comment <- @comments do %>
        <.comment_item
          comment={comment}
          current_user={@current_user}
          depth={@depth}
        />
      <% end %>
    </div>
    """
  end

  # 1件のコメントと、その子コメントを表示する
  attr :comment,      :map,     required: true
  attr :current_user, :map,     default: nil
  attr :depth,        :integer, default: 0

  defp comment_item(assigns) do
    ~H"""
    <div class="mb-2">
      <%!-- コメント本体 --%>
      <div class="flex gap-2">

        <%!-- 投票ボタン --%>
        <div class="flex flex-col items-center gap-0.5 pt-1">
          <button
            phx-click="vote_comment"
            phx-value-id={@comment.id}
            phx-value-value="1"
            class="text-gray-300 hover:text-orange-500 text-xs"
          >
            ▲
          </button>
          <span class="text-xs text-gray-500"><%= @comment.score %></span>
          <button
            phx-click="vote_comment"
            phx-value-id={@comment.id}
            phx-value-value="-1"
            class="text-gray-300 hover:text-blue-500 text-xs"
          >
            ▼
          </button>
        </div>

        <%!-- コメント内容 --%>
        <div class="flex-1 border-l-2 border-gray-100 pl-2">

          <%!-- メタ情報 --%>
          <div class="text-xs text-gray-500 mb-1">
            <span class="font-medium text-gray-700">
              u/<%= @comment.author.username %>
            </span>
            • <%= time_ago(@comment.inserted_at) %>
            • <%= @comment.score %> ポイント
          </div>

          <%!-- 本文 --%>
          <p class="text-sm text-gray-800 whitespace-pre-wrap"><%= @comment.body %></p>

          <%!-- アクションボタン --%>
          <div class="flex gap-3 mt-1">
            <%= if @current_user do %>
              <button
                phx-click="reply_to"
                phx-value-id={@comment.id}
                class="text-xs text-gray-400 hover:text-gray-600"
              >
                返信
              </button>
            <% end %>

            <%= if can_delete?(@current_user, @comment) do %>
              <button
                phx-click="delete_comment"
                phx-value-id={@comment.id}
                data-confirm="このコメントを削除しますか？"
                class="text-xs text-red-400 hover:text-red-600"
              >
                削除
              </button>
            <% end %>

            <%= if can_report?(@current_user, @comment) do %>
              <button
                phx-click="open_report_modal"
                phx-value-type="comment"
                phx-value-id={@comment.id}
                class="text-xs text-gray-400 hover:text-gray-600"
              >
                報告
              </button>
            <% end %>
          </div>

        </div>
      </div>

      <%!-- 子コメント（再帰）--%>
      <%= if @comment.replies != [] && @depth < @max_depth do %>
        <div class="ml-6 mt-1">
          <.comment_tree
            comments={@comment.replies}
            current_user={@current_user}
            depth={@depth + 1}
          />
        </div>
      <% end %>

    </div>
    """
  end

  # 深さに応じてインデントを調整する
  defp depth_class(0), do: ""
  defp depth_class(_), do: "border-l border-gray-200 pl-2"

  # 自分のコメントのみ削除できる
  defp can_delete?(nil, _comment), do: false
  defp can_delete?(user, comment),  do: user.id == comment.author_id

  # 自分のコメント以外を報告できる（ログイン必須）
  defp can_report?(nil, _comment), do: false
  defp can_report?(user, comment),  do: user.id != comment.author_id
end
```

---

### 再帰コンポーネントの仕組み

CommentTree が再帰的に動作する仕組みを図で説明します。

```
PostLive が呼び出す
  <.comment_tree comments={[A, E]} depth={0} />

comment_tree は A を処理する
  <.comment_item comment={A} depth={0} />
    A の本文を表示
    A の replies が [B, D] なので
      <.comment_tree comments={[B, D]} depth={1} />  ← 再帰！

        comment_tree は B を処理する
          <.comment_item comment={B} depth={1} />
            B の本文を表示
            B の replies が [C] なので
              <.comment_tree comments={[C]} depth={2} />  ← さらに再帰！

                comment_tree は C を処理する
                  <.comment_item comment={C} depth={2} />
                    C の本文を表示
                    C の replies が [] なので再帰しない ← 終了
```

`@depth < @max_depth` で最大8階層に制限します。極端に深いネストが画面を圧迫するのを防ぎます。

**depth による視覚的なインデント**

```elixir
defp depth_class(0), do: ""                         # トップレベルは余白なし
defp depth_class(_), do: "border-l border-gray-200 pl-2"  # 深くなるほど左に線が増える
```

深さが増えるごとに左ボーダーが追加され、ネスト構造が視覚的に表現されます。

**`defp` と `def` の使い分け**

```elixir
def comment_tree(assigns) do ...   # public（PostLive から呼ばれる）
defp comment_item(assigns) do ...  # private（comment_tree からのみ呼ばれる）
```

`comment_item` はこのモジュール内部だけで使うため `defp` にしています。外部から直接呼ばれる必要がない関数は `defp` で隠蔽するのが Elixir の慣習です。

**読み解き**

CommentTree も、状態を持たない部品です。返信・削除・報告のボタンは、すべて PostLive に届きます。CommentTree を使うのは PostLive だけなので、受け手も PostLive にそろっています。

`can_delete?` / `can_report?` は、「ボタンを出すかどうか」という表示の判定です。実際に削除できるかの最終判断は、Context（第4章）が行います（第6章の PostLive で見たとおり、画面から Context に渡して結果を受けます）。「表示の判定は部品、実行の判定は Context」という分担が、ここにも表れています。

なお、CommentTree が前提にしているのは「ツリー構造に組み立てられたコメント」です。フラットな一覧を渡しても、入れ子にはなりません。組み立ては第4章の `Comments.list_comments/1`（`build_tree`）の仕事です。

---

## 7-5　ReportModal コンポーネント

ReportModal は、投稿とコメントの報告に使うモーダル（画面の上に重ねて出す小窓）です。コードの冒頭（`@moduledoc`）にあるとおり、SubredditLive / PostLive / HomeFeedLive / ProfileLive / SearchLive の**5画面**から使う共通部品です。

```elixir
# lib/reddit_clone_web/live/components/report_modal.ex
defmodule RedditCloneWeb.Components.ReportModal do
  @moduledoc """
  投稿・コメントへの報告モーダル。
  SubredditLive / PostLive / HomeFeedLive / ProfileLive / SearchLive から使う。
  """

  use RedditCloneWeb, :html

  @reasons [
    {"spam",           "スパム"},
    {"harassment",     "嫌がらせ・ハラスメント"},
    {"hate_speech",    "ヘイトスピーチ"},
    {"misinformation", "誤情報"},
    {"other",          "その他"}
  ]

  @doc """
  報告モーダルを表示する。

  ## 属性
    - report_modal: %{target_type: "post"|"comment", target_id: id} | nil
  """
  attr :report_modal, :map, default: nil

  def report_modal(assigns) do
    assigns = assign(assigns, :reasons, @reasons)

    ~H"""
    <%= if @report_modal do %>
      <%!-- 背景オーバーレイ --%>
      <div
        class="fixed inset-0 bg-black bg-opacity-50 z-40"
        phx-click="close_report_modal"
      />

      <%!-- モーダル本体 --%>
      <div class="fixed inset-0 z-50 flex items-center justify-center p-4">
        <div class="bg-white rounded-lg shadow-xl w-full max-w-md">

          <%!-- ヘッダー --%>
          <div class="flex justify-between items-center p-4 border-b border-gray-200">
            <h2 class="text-lg font-bold">報告する</h2>
            <button
              phx-click="close_report_modal"
              class="text-gray-400 hover:text-gray-600 text-xl"
            >
              ✕
            </button>
          </div>

          <%!-- 理由の選択 --%>
          <div class="p-4">
            <p class="text-sm text-gray-600 mb-3">
              報告する理由を選択してください
            </p>

            <div class="space-y-2">
              <%= for {value, label} <- @reasons do %>
                <button
                  phx-click="submit_report"
                  phx-value-reason={value}
                  phx-value-target_type={@report_modal.target_type}
                  phx-value-target_id={@report_modal.target_id}
                  class="w-full text-left px-4 py-3 rounded border border-gray-200 text-sm hover:bg-gray-50 hover:border-gray-300 transition-colors"
                >
                  <%= label %>
                </button>
              <% end %>
            </div>
          </div>

          <%!-- フッター --%>
          <div class="p-4 border-t border-gray-100">
            <button
              phx-click="close_report_modal"
              class="w-full py-2 text-sm text-gray-500 hover:text-gray-700"
            >
              キャンセル
            </button>
          </div>

        </div>
      </div>
    <% end %>
    """
  end
end
```

**読み解き**

モーダルの表示・非表示は `report_modal` assigns で制御します。

```elixir
# 閉じているとき
assign(:report_modal, nil)

# 開いているとき
assign(:report_modal, %{target_type: "post", target_id: "abc-123"})
```

`<%= if @report_modal do %>` で `nil` のときは何も描画しません。

背景のオーバーレイにも `phx-click="close_report_modal"` をつけています。モーダルの外側をクリックしても閉じられるようにするためです。

```heex
<div class="fixed inset-0 bg-black bg-opacity-50 z-40"
  phx-click="close_report_modal" />
```

`@reasons` はモジュール属性として定義してから `assigns` に追加します。

```elixir
@reasons [{"spam", "スパム"}, ...]

def report_modal(assigns) do
  assigns = assign(assigns, :reasons, @reasons)  # assigns に追加
  ~H"""
  <%= for {value, label} <- @reasons do %>  ← テンプレートで使える
  """
end
```

モジュール属性をテンプレートで直接使うことはできません。`assign/3` で `assigns` に入れることでテンプレートから `@reasons` としてアクセスできます。

そして、この部品は「部品と画面の分担」が一番はっきり表れる例です。ReportModal 自身は、「開いているかどうか」の状態を持ちません。今開いているかは画面側の assigns（`report_modal`）が決め、開く・閉じる・送信の3つのイベントの受け手も画面側にあります。部品は「`report_modal` が `nil` でなければ、この形で出す」ことだけを知っています。状態を画面側に置いたからこそ、5つの画面が同じ部品をそのまま共有できました。

この分担を崩すとどうなるか、実際に起きた例があります。以前の版では、受け手の3つのハンドラが SubredditLive と PostLive にしか無く、HomeFeedLive・ProfileLive・SearchLive では、PostCard の「報告」ボタンを押すと受け手が無いために LiveView がエラーで落ちていました（検証のときに見つかった不整合で、本書の完成コードでは5画面すべてに受け手を用意して直してあります。第6章の各画面にも、同じ3点セットが入っています）。部品を新しい画面に置くときは、「この部品が送るイベントを、その画面が全部受けられるか」を確かめるのが教訓です。

---

## 動作確認（この章の仕上げ）

前提: 第6章が済み、各画面から部品が呼ばれる状態になっていること（組み立てたプロジェクトの環境で確認します）。

- [ ] 投稿カードが、コミュニティページ・ホーム Feed・プロフィール・検索結果の4画面で、同じ見た目で表示される
- [ ] リンク投稿のカードにはドメイン名が、テキスト投稿のカードには「text」と表示される
- [ ] コメントが入れ子で表示され、返信のたびに一段深くなる。深さ8でそれ以上は深くならない
- [ ] 自分のコメントには「削除」、他人のコメントには「報告」が出る。未ログインではどちらも出ない
- [ ] 報告モーダルが5画面すべてで開き、背景クリックと「キャンセル」と「✕」のどれでも閉じる。理由を選ぶと報告が送信される

---

## よくあるエラーと対処

| 症状 | 原因 | 直し方 |
|------|------|--------|
| 「報告」ボタンを押すと LiveView が落ちる | その画面に、イベントの受け手（`handle_event("open_report_modal", ...)` など）が無い | 部品を使う画面のすべてに、開く・閉じる・送信の3ハンドラを用意する（実際に起きた不整合の例です。本文の 7-5 を参照） |
| コンパイル時に、必須の attr が無いという警告が出る | 呼び出し側で `post={...}` のような必須の値を渡し忘れている | 呼び出し側で、部品の `attr` 宣言に沿って値を渡す |
| 渡した値の型が違うという警告が出る | `attr` で宣言した型と違う値を渡している（例: `depth` に文字列） | 呼び出し側で型を合わせる。attr は部品と画面の約束なので、部品側の宣言をむやみに緩めない |
| モーダルが開かない・開いたまま閉じない | 表示の状態（`report_modal` assigns）を、画面側が切り替えていない | 開く・閉じるハンドラで assigns を切り替える。部品の側では状態を持たないので、部品を直しても直りません |
| コメントが入れ子にならず、平らに並ぶ | CommentTree に、フラットな一覧を渡している | 第4章の `Comments.list_comments/1` がツリー構造（`replies` 入り）を返しているか確認する |

---

## 確認問題

1. 関数コンポーネントが「状態を持たない」とは、どういうことですか。PostCard の報告ボタンを例に、クリックがどこへ届くかを説明してください。
2. `time_ago/1` をコンポーネントにせず、Helpers の関数にした判断の基準は何ですか。
3. CommentTree の再帰が止まる条件は2つあります。何と何ですか。
4. ReportModal を5画面で共有できるのは、表示の状態を誰が持っているからですか。

---

## まとめと次章へのつながり

この章では以下を完了しました。

```
✅ コンポーネントの概念と利点を理解した
✅ Helpers（time_ago / domain）を共通化した
✅ PostCard コンポーネントを実装した
✅ CommentTree の再帰コンポーネントを実装した
✅ ReportModal コンポーネントを実装した
```

**この章の重要なポイント**

- `attr` でプロパティを宣言するとコンパイル時に型チェックが行われる
- 再帰コンポーネントは `depth` を引数として渡し `max_depth` で制限する
- モーダルの表示状態は `assigns` の `nil` チェックで制御する
- モジュール属性はテンプレートで直接使えないので `assign/3` で追加する
- 内部でのみ使う関数は `defp` で隠蔽する
- 部品は状態を持たず、状態とイベントの受け手は画面が持つ

次の章では仕上げとして、レイアウトにナビゲーションバーを実装し、アプリ全体の動作確認を行います。

---

## 確認問題の答え

1. 部品は、受け取った値から HTML を作るだけで、「今どういう状態か」を自分では保持しません。報告ボタンのクリック（`open_report_modal`）は、その PostCard を表示している LiveView に届き、LiveView の `handle_event/3` が処理します。
2. 「HTML を返すかどうか」です。`time_ago/1` は文字列を返すだけで見た目を持たないので、普通の関数として切り出しました。見た目を持つものだけをコンポーネントにします。
3. 子コメントが無いこと（`@comment.replies == []`）と、深さが上限に達すること（`@depth` が `@max_depth` の8以上）です。どちらか一方でも欠けると、終わりのない構造や、深すぎる表示を防げません。
4. 画面（LiveView）です。部品は「`report_modal` が `nil` でなければ出す」ことだけを知っていて、開閉の判断と状態の保持は各画面の assigns とハンドラにあります。そのため、部品をそのまま5画面で共有できました。
