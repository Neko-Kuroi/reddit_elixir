# 第7章　コンポーネント（前編）

---

## 7-1　コンポーネントとは

コンポーネントとは**再利用可能な UI の部品**です。

例えば投稿カードは SubredditLive・HomeFeedLive・ProfileLive・SearchLive の4つの画面で表示されます。同じ HTML を4箇所に書くと、デザインを変えたいときに全箇所を修正しなければなりません。

コンポーネントにまとめると1箇所の修正で全画面に反映されます。

```elixir
# 各 LiveView で
<.post_card post={post} show_subreddit={true} current_user={@current_user} />
```

Phoenix LiveView のコンポーネントは**関数コンポーネント**として実装します。`attr` でプロパティを定義し、`~H` でテンプレートを書きます。

---

## 7-2　Helpers（共通ヘルパー関数）

複数のコンポーネントで使う関数を1つのモジュールにまとめます。

```elixir
# lib/reddit_clone_web/helpers.ex
defmodule RedditCloneWeb.Helpers do
  @doc """
  DateTime を相対時間文字列に変換する。
  例: 3時間前・2日前
  """
  def time_ago(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime)

    cond do
      diff < 60           -> "たった今"
      diff < 3_600        -> "#{div(diff, 60)}分前"
      diff < 86_400       -> "#{div(diff, 3_600)}時間前"
      diff < 86_400 * 30  -> "#{div(diff, 86_400)}日前"
      true                -> "#{div(diff, 86_400 * 30)}ヶ月前"
    end
  end

  @doc """
  URL からドメイン名だけを取り出す。
  例: "https://github.com/elixir" → "github.com"
  """
  def domain(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{host: host} when is_binary(host) -> host
      _ -> url
    end
  end
  def domain(_), do: ""
end
```

**解説**

`time_ago/1` は `cond` で複数の条件を順番に評価します。最初に真になった条件の結果を返します。

```elixir
cond do
  diff < 60    -> "たった今"    # 60秒未満
  diff < 3_600 -> "○分前"      # 1時間未満
  ...
end
```

`div/2` は整数の除算です。`div(150, 60)` は `2`（2分前）を返します。

`URI.parse/1` は Elixir 標準ライブラリの関数です。URL を解析して `%URI{}` 構造体に変換します。ホスト名だけを安全に取り出せます。

このモジュールは各コンポーネントで `import RedditCloneWeb.Helpers` して使います。

---

## 7-3　PostCard コンポーネント

```elixir
# lib/reddit_clone_web/live/components/post_card.ex
defmodule RedditCloneWeb.Components.PostCard do
  use RedditCloneWeb, :html

  import RedditCloneWeb.Helpers

  attr :post,           :map,     required: true
  attr :show_subreddit, :boolean, default: false
  attr :current_user,   :map,     default: nil

  def post_card(assigns) do
    ~H"""
    <div class="bg-white border border-gray-200 rounded hover:border-gray-400 mb-2 flex">

      <%!-- 左側: 投票エリア --%>
      <div class="bg-gray-50 w-10 flex flex-col items-center py-2 gap-1 rounded-l">
        <button
          phx-click="vote"
          phx-value-id={@post.id}
          phx-value-type="post"
          phx-value-value="1"
          class="text-gray-400 hover:text-orange-500"
        >▲</button>
        <span class="text-xs font-bold text-gray-700"><%= @post.score %></span>
        <button
          phx-click="vote"
          phx-value-id={@post.id}
          phx-value-type="post"
          phx-value-value="-1"
          class="text-gray-400 hover:text-blue-500"
        >▼</button>
      </div>

      <%!-- 右側: 投稿内容 --%>
      <div class="p-2 flex-1">

        <%!-- タイトル + タイプバッジ --%>
        <div class="flex items-start gap-2">
          <.link navigate={post_url(@post)}
            class="text-sm font-medium text-gray-900 hover:underline flex-1">
            <%= @post.title %>
          </.link>

          <%= if @post.type == "link" do %>
            <a href={@post.url} target="_blank" rel="noopener noreferrer"
              class="text-xs text-blue-500 hover:underline whitespace-nowrap">
              <%= domain(@post.url) %> ↗
            </a>
          <% else %>
            <span class="text-xs text-gray-400">text</span>
          <% end %>
        </div>

        <%!-- メタ情報 --%>
        <div class="flex items-center gap-2 mt-1 text-xs text-gray-500">
          <%= if @show_subreddit do %>
            <.link navigate={~p"/r/#{@post.subreddit.name}"} class="font-medium hover:underline">
              r/<%= @post.subreddit.name %>
            </.link>
            <span>•</span>
          <% end %>
          <span>
            投稿者
            <.link navigate={~p"/u/#{@post.author.username}"} class="hover:underline">
              u/<%= @post.author.username %>
            </.link>
          </span>
          <span>•</span>
          <span><%= time_ago(@post.inserted_at) %></span>
        </div>

        <%!-- コメント数 + 報告ボタン --%>
        <div class="mt-1 flex items-center gap-2">
          <.link navigate={post_url(@post)}
            class="text-xs text-gray-500 hover:bg-gray-100 px-1 py-0.5 rounded">
            💬 <%= @post.comment_count || 0 %> コメント
          </.link>

          <%= if @current_user && @current_user.id != @post.author_id do %>
            <button
              phx-click="open_report_modal"
              phx-value-type="post"
              phx-value-id={@post.id}
              class="text-xs text-gray-400 hover:text-gray-600 px-1 py-0.5 rounded hover:bg-gray-100"
            >報告</button>
          <% end %>
        </div>

      </div>
    </div>
    """
  end

  defp post_url(post) do
    "/r/#{post.subreddit.name}/#{post.id}"
  end
end
```

**解説**

`attr` でコンポーネントのプロパティを宣言します。

```elixir
attr :post,           :map,     required: true   # 必須
attr :show_subreddit, :boolean, default: false   # 省略可能（デフォルト false）
attr :current_user,   :map,     default: nil     # 省略可能（デフォルト nil）
```

`required: true` のプロパティを渡さないとコンパイル時に警告が出ます。型の安全性がコンパイル時に保証されます。

`show_subreddit` は表示コンテキストによって切り替えます。

```heex
<.post_card post={post} show_subreddit={false} .../>  ← SubredditLive（r/○○は不要）
<.post_card post={post} show_subreddit={true}  .../>  ← HomeFeedLive（r/○○を表示）
```

報告ボタンは自分の投稿には表示しません。

```heex
<%= if @current_user && @current_user.id != @post.author_id do %>
```

未ログイン（`current_user` が `nil`）のときも非表示になります。

`post_url/1` は `~p` の検証機能を使わずに直接文字列で URL を組み立てています。コンポーネントは LiveView ではないため `verified_routes` が使えない場合があるためです。

---

後編では CommentTree と ReportModal を実装します。
