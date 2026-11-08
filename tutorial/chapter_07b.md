# 第7章　コンポーネント（後編）

---

## 7-4　CommentTree（再帰コンポーネント）

CommentTree はコメントをネスト構造で表示する再帰コンポーネントです。

```elixir
# lib/reddit_clone_web/live/components/comment_tree.ex
defmodule RedditCloneWeb.Components.CommentTree do
  use RedditCloneWeb, :html

  import RedditCloneWeb.Helpers

  @max_depth 8

  attr :comments,     :list,    required: true
  attr :current_user, :map,     default: nil
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

  attr :comment,      :map,     required: true
  attr :current_user, :map,     default: nil
  attr :depth,        :integer, default: 0

  defp comment_item(assigns) do
    ~H"""
    <div class="mb-2">
      <div class="flex gap-2">

        <%!-- 投票ボタン --%>
        <div class="flex flex-col items-center gap-0.5 pt-1">
          <button phx-click="vote_comment" phx-value-id={@comment.id} phx-value-value="1"
            class="text-gray-300 hover:text-orange-500 text-xs">▲</button>
          <span class="text-xs text-gray-500"><%= @comment.score %></span>
          <button phx-click="vote_comment" phx-value-id={@comment.id} phx-value-value="-1"
            class="text-gray-300 hover:text-blue-500 text-xs">▼</button>
        </div>

        <%!-- コメント内容 --%>
        <div class="flex-1 border-l-2 border-gray-100 pl-2">
          <div class="text-xs text-gray-500 mb-1">
            <span class="font-medium text-gray-700">u/<%= @comment.author.username %></span>
            • <%= time_ago(@comment.inserted_at) %>
            • <%= @comment.score %> ポイント
          </div>

          <p class="text-sm text-gray-800 whitespace-pre-wrap"><%= @comment.body %></p>

          <div class="flex gap-3 mt-1">
            <%= if @current_user do %>
              <button phx-click="reply_to" phx-value-id={@comment.id}
                class="text-xs text-gray-400 hover:text-gray-600">返信</button>
            <% end %>

            <%= if can_delete?(@current_user, @comment) do %>
              <button phx-click="delete_comment" phx-value-id={@comment.id}
                data-confirm="このコメントを削除しますか？"
                class="text-xs text-red-400 hover:text-red-600">削除</button>
            <% end %>

            <%= if can_report?(@current_user, @comment) do %>
              <button phx-click="open_report_modal"
                phx-value-type="comment" phx-value-id={@comment.id}
                class="text-xs text-gray-400 hover:text-gray-600">報告</button>
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

  defp depth_class(0), do: ""
  defp depth_class(_), do: "border-l border-gray-200 pl-2"

  defp can_delete?(nil, _comment), do: false
  defp can_delete?(user, comment),  do: user.id == comment.author_id

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

---

## 7-5　ReportModal コンポーネント

```elixir
# lib/reddit_clone_web/live/components/report_modal.ex
defmodule RedditCloneWeb.Components.ReportModal do
  use RedditCloneWeb, :html

  @reasons [
    {"spam",           "スパム"},
    {"harassment",     "嫌がらせ・ハラスメント"},
    {"hate_speech",    "ヘイトスピーチ"},
    {"misinformation", "誤情報"},
    {"other",          "その他"}
  ]

  attr :report_modal, :map, default: nil

  def report_modal(assigns) do
    assigns = assign(assigns, :reasons, @reasons)

    ~H"""
    <%= if @report_modal do %>
      <%!-- 背景オーバーレイ --%>
      <div class="fixed inset-0 bg-black bg-opacity-50 z-40"
        phx-click="close_report_modal" />

      <%!-- モーダル本体 --%>
      <div class="fixed inset-0 z-50 flex items-center justify-center p-4">
        <div class="bg-white rounded-lg shadow-xl w-full max-w-md">

          <div class="flex justify-between items-center p-4 border-b border-gray-200">
            <h2 class="text-lg font-bold">報告する</h2>
            <button phx-click="close_report_modal"
              class="text-gray-400 hover:text-gray-600 text-xl">✕</button>
          </div>

          <div class="p-4">
            <p class="text-sm text-gray-600 mb-3">報告する理由を選択してください</p>

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

          <div class="p-4 border-t border-gray-100">
            <button phx-click="close_report_modal"
              class="w-full py-2 text-sm text-gray-500 hover:text-gray-700">
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

**解説**

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

---

## まとめ

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

次の章では仕上げとしてナビゲーションバーを実装し、アプリの動作確認を行います。
