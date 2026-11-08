# 第7章　コンポーネント（前編）

---

### この章で学ぶこと

- 作るもの: 画面の部品4つ。Helpers（共通の関数）、PostCard（投稿カード）、CommentTree（コメントの木）、ReportModal（報告モーダル）。前編では Helpers と PostCard、後編では CommentTree と ReportModal を扱います
- 学ぶ考え方: 関数コンポーネントと `attr`（部品が受け取る値の約束）、状態を持たない部品と状態を持つ画面の分担、再帰コンポーネント、共通化の判断基準（部品にするか、ただの関数にするか）

### 前提

- 第6章が済んでいること（各画面が、すでに PostCard などの部品を呼び出す形で書かれていること）。この章では、その部品の中身を作ります

### 全体の中での位置

Web 層の中の「部品置き場」です。画面（LiveView）が増えると、同じ表示が何画面にも現れます。その重なりを切り出して、1か所で直せるようにするのがこの章の役割です。

> この章のコードについて: 部品のファイルは、`@moduledoc`（モジュールの説明）と `@doc`（関数の説明）も含めて、実ファイルの全文を掲載しています。部品は「使い方の説明が、そのまま他の画面との約束になる」ためです（第4・5章で `@doc` を省略した扱いとは、ここだけ変えています）。全文は全コード付録3（appendix_code_03_web.md）にも収録しています。

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

**読み解き**

関数コンポーネントは、その名のとおり「関数」です。受け取った値（assigns）から HTML を作って返すだけで、**自分では状態を持ちません**。ボタンのクリックのような操作も、部品自身は処理しません。`phx-click` のイベントは、その部品を表示している LiveView に届き、LiveView の `handle_event/3` が処理します。

分担はこうなります。

- 部品: 見た目と、「どのイベントを送るか」まで
- 画面（LiveView）: 状態（assigns）と、イベントの受け手（`handle_event/3`）

この分担のおかげで、PostCard は「どの画面に置かれても同じ見た目」でいられます。反対に、部品が送るイベントの受け手を画面側が用意し忘れると、ボタンを押しても行き先が無くなります。このことは、後編の ReportModal の節で、実際に起きた例として取り上げます。

---

## 7-2　Helpers（共通ヘルパー関数）

複数のコンポーネントで使う関数を1つのモジュールにまとめます。

```elixir
# lib/reddit_clone_web/helpers.ex
defmodule RedditCloneWeb.Helpers do
  @moduledoc """
  画面コンポーネント共通のヘルパー関数。
  post_card.ex / comment_tree.ex などから import して使う。
  """

  @doc """
  DateTime を「3時間前」のような相対時間文字列に変換する。

  ## 例
      iex> time_ago(~U[2024-01-01 00:00:00Z])
      "3日前"
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
  URLからドメイン名だけを取り出す。

  ## 例
      iex> domain("https://github.com/elixir-lang/elixir")
      "github.com"

      iex> domain("不正なURL")
      "不正なURL"
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

**読み解き**

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

`@doc` の中で `iex>` から始まる例は、**doctest**（ドキュメントの中の実行例を、そのままテストとして動かせる仕組み）として書かれています。説明と例が食い違ったら、テストで気づけます（テストを書くこと自体は、本書の範囲外です）。

なぜこの2つの関数は、コンポーネントではなく普通の関数のモジュールにまとめたのでしょうか。基準は「HTML を返すかどうか」です。`time_ago/1` と `domain/1` は文字列を返すだけで、見た目を持ちません。見た目を持たない共通処理は関数として切り出し、見た目を持つものだけをコンポーネントにします。共通化で迷ったときの物差しになります。

このモジュールは各コンポーネントで `import RedditCloneWeb.Helpers` して使います。

---

## 7-3　PostCard コンポーネント

PostCard は、投稿1件分のカード表示です。コードの冒頭（`@moduledoc`）では「SubredditLive と HomeFeedLive で共通して使う」と書かれていますが、実際には第6章で見たとおり、ProfileLive と SearchLive でも使われています（合計4画面）。

```elixir
# lib/reddit_clone_web/live/components/post_card.ex
defmodule RedditCloneWeb.Components.PostCard do
  @moduledoc """
  Feed上の投稿1件を表示するコンポーネント。
  SubredditLive と HomeFeedLive で共通して使う。
  """

  use RedditCloneWeb, :html

  import RedditCloneWeb.Helpers

  @doc """
  投稿カードを表示する。

  ## 属性
    - post: %Post{} （author をpreloadしておくこと）
    - show_subreddit: true の場合 r/○○ を表示する（ホームFeed用）
  """
  attr :post, :map, required: true
  attr :show_subreddit, :boolean, default: false
  attr :current_user, :map, default: nil

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
        >
          ▲
        </button>
        <span class="text-xs font-bold text-gray-700"><%= @post.score %></span>
        <button
          phx-click="vote"
          phx-value-id={@post.id}
          phx-value-type="post"
          phx-value-value="-1"
          class="text-gray-400 hover:text-blue-500"
        >
          ▼
        </button>
      </div>

      <%!-- 右側: 投稿内容 --%>
      <div class="p-2 flex-1">

        <%!-- タイトル + タイプバッジ --%>
        <div class="flex items-start gap-2">
          <.link
            navigate={post_url(@post)}
            class="text-sm font-medium text-gray-900 hover:underline flex-1"
          >
            <%= @post.title %>
          </.link>

          <%= if @post.type == "link" do %>
            <a
              href={@post.url}
              target="_blank"
              rel="noopener noreferrer"
              class="text-xs text-blue-500 hover:underline whitespace-nowrap"
            >
              <%= domain(@post.url) %> ↗
            </a>
          <% else %>
            <span class="text-xs text-gray-400">text</span>
          <% end %>
        </div>

        <%!-- メタ情報 --%>
        <div class="flex items-center gap-2 mt-1 text-xs text-gray-500">
          <%= if @show_subreddit do %>
            <.link
              navigate={~p"/r/#{@post.subreddit.name}"}
              class="font-medium hover:underline"
            >
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
          <.link
            navigate={post_url(@post)}
            class="text-xs text-gray-500 hover:bg-gray-100 px-1 py-0.5 rounded"
          >
            💬 <%= @post.comment_count || 0 %> コメント
          </.link>

          <%= if @current_user && @current_user.id != @post.author_id do %>
            <button
              phx-click="open_report_modal"
              phx-value-type="post"
              phx-value-id={@post.id}
              class="text-xs text-gray-400 hover:text-gray-600 px-1 py-0.5 rounded hover:bg-gray-100"
            >
              報告
            </button>
          <% end %>
        </div>

      </div>
    </div>
    """
  end

  # 投稿のURLを生成する
  defp post_url(post) do
    "/r/#{post.subreddit.name}/#{post.id}"
  end
end
```

**読み解き**

`attr` でコンポーネントのプロパティを宣言します。

```elixir
attr :post,           :map,     required: true   # 必須
attr :show_subreddit, :boolean, default: false   # 省略可能（デフォルト false）
attr :current_user,   :map,     default: nil     # 省略可能（デフォルト nil）
```

これは、部品の側から見た「受け取る値の約束」です。`required: true` のプロパティを渡さないとコンパイル時に警告が出ます。型の安全性がコンパイル時に保証されます。

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

最後に、7-1 で触れた分担をこの部品で確かめます。投票ボタンと報告ボタンには `phx-click`（`"vote"` と `"open_report_modal"`）がありますが、PostCard の中には `handle_event` はありません。クリックは、表示中の LiveView に届きます。したがって、PostCard を置く画面には `vote` と `open_report_modal` の受け手が要ります。第6章で、PostCard を使う画面のすべてに受け手を用意したのは、このためです。

---

後編では CommentTree と ReportModal を実装します。
