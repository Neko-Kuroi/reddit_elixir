# 第6章　画面実装（LiveView）後編

---

## 6-6　HomeFeedLive

HomeFeedLive はログイン済みユーザーのホームページです。Join 済みコミュニティの投稿を Hot/New 順で表示します。

```elixir
# lib/reddit_clone_web/live/home_feed_live.ex
defmodule RedditCloneWeb.HomeFeedLive do
  use RedditCloneWeb, :live_view

  import RedditCloneWeb.Components.PostCard

  alias RedditClone.Communities
  alias RedditClone.Posts

  on_mount {RedditCloneWeb.UserAuth, :require_auth}

  @impl true
  def mount(_params, _session, socket) do
    user              = socket.assigns.current_user
    posts             = Posts.list_home_posts(user.id, "hot", 1)
    joined_subreddits = Communities.list_joined_subreddits(user.id)

    {:ok,
     socket
     |> assign(:page_title, "ホーム")
     |> assign(:posts, posts)
     |> assign(:sort, "hot")
     |> assign(:page, 1)
     |> assign(:has_more?, length(posts) == 25)
     |> assign(:joined_subreddits, joined_subreddits)}
  end

  @impl true
  def handle_event("sort", %{"value" => sort}, socket) do
    user  = socket.assigns.current_user
    posts = Posts.list_home_posts(user.id, sort, 1)

    {:noreply,
     socket
     |> assign(:sort, sort)
     |> assign(:page, 1)
     |> assign(:has_more?, length(posts) == 25)
     |> assign(:posts, posts)}
  end

  def handle_event("load_more", _params, socket) do
    user      = socket.assigns.current_user
    next_page = socket.assigns.page + 1
    new_posts = Posts.list_home_posts(user.id, socket.assigns.sort, next_page)

    {:noreply,
     socket
     |> assign(:page, next_page)
     |> assign(:has_more?, length(new_posts) == 25)
     |> assign(:posts, socket.assigns.posts ++ new_posts)}
  end

  def handle_event("vote", %{"id" => post_id, "value" => value}, socket) do
    case Posts.vote_post(socket.assigns.current_user.id, post_id, String.to_integer(value)) do
      {:ok, updated_post} ->
        posts = Enum.map(socket.assigns.posts, fn post ->
          if post.id == updated_post.id, do: updated_post, else: post
        end)
        {:noreply, assign(socket, :posts, posts)}

      {:error, :cannot_vote_own_post} ->
        {:noreply, put_flash(socket, :error, "自分の投稿には投票できません")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto px-4 py-4 flex gap-4">

      <%!-- 左サイドバー --%>
      <div class="w-48 shrink-0">
        <div class="bg-white border border-gray-200 rounded p-3">
          <h2 class="text-xs font-bold text-gray-500 uppercase mb-2">参加中</h2>

          <%= if @joined_subreddits == [] do %>
            <p class="text-xs text-gray-400">まだ参加していません</p>
          <% else %>
            <%= for subreddit <- @joined_subreddits do %>
              <.link navigate={~p"/r/#{subreddit.name}"}
                class="block text-sm py-1 hover:text-blue-500 truncate">
                r/<%= subreddit.name %>
              </.link>
            <% end %>
          <% end %>

          <div class="border-t border-gray-100 mt-3 pt-3">
            <.link navigate={~p"/subreddits/new"}
              class="text-sm text-blue-500 hover:underline">
              ＋ コミュニティを作成
            </.link>
          </div>
        </div>
      </div>

      <%!-- メインカラム --%>
      <div class="flex-1">
        <div class="bg-white border border-gray-200 rounded p-2 mb-4 flex gap-2">
          <button phx-click="sort" phx-value-value="hot" class={tab_class(@sort, "hot")}>
            🔥 Hot
          </button>
          <button phx-click="sort" phx-value-value="new" class={tab_class(@sort, "new")}>
            ✨ New
          </button>
        </div>

        <%= if @posts == [] do %>
          <div class="bg-white border border-gray-200 rounded p-8 text-center">
            <p class="text-gray-500 mb-2">まだ投稿がありません</p>
            <p class="text-sm text-gray-400">コミュニティに参加して投稿を見てみましょう</p>
            <.link navigate={~p"/subreddits/new"}
              class="inline-block mt-4 px-4 py-2 bg-blue-500 text-white text-sm rounded hover:bg-blue-600">
              コミュニティを探す
            </.link>
          </div>
        <% else %>
          <%= for post <- @posts do %>
            <.post_card post={post} show_subreddit={true} current_user={@current_user} />
          <% end %>

          <%= if @has_more? do %>
            <div class="text-center py-4">
              <button phx-click="load_more"
                class="px-6 py-2 border border-gray-300 rounded text-sm text-gray-600 hover:bg-gray-50">
                もっと見る
              </button>
            </div>
          <% end %>
        <% end %>
      </div>

    </div>
    """
  end

  defp tab_class(current, tab) when current == tab,
    do: "px-4 py-1 rounded bg-gray-200 font-bold text-sm"
  defp tab_class(_, _),
    do: "px-4 py-1 rounded hover:bg-gray-100 text-sm text-gray-600"
end
```

**解説**

HomeFeedLive は `require_auth` で保護されているため、`vote` イベントで `nil` チェックが不要です。

```elixir
# SubredditLive では nil チェックが必要（未ログインでも見られるため）
case socket.assigns.current_user do
  nil -> ...
  user -> ...
end

# HomeFeedLive では不要（ログイン済みが保証されているため）
Posts.vote_post(socket.assigns.current_user.id, ...)
```

---

## 6-7　ProfileLive

```elixir
# lib/reddit_clone_web/live/profile_live.ex
defmodule RedditCloneWeb.ProfileLive do
  use RedditCloneWeb, :live_view

  import RedditCloneWeb.Components.PostCard

  alias RedditClone.Accounts
  alias RedditClone.Posts

  on_mount {RedditCloneWeb.UserAuth, :fetch_current_user}

  @impl true
  def mount(%{"username" => username}, _session, socket) do
    case Accounts.get_user_by_username(username) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "u/#{username} は存在しません")
         |> redirect(to: "/")}

      profile_user ->
        posts = Posts.list_user_posts(profile_user.id, 1)

        {:ok,
         socket
         |> assign(:page_title, "u/#{profile_user.username}")
         |> assign(:profile_user, profile_user)
         |> assign(:posts, posts)
         |> assign(:page, 1)
         |> assign(:has_more?, length(posts) == 25)}
    end
  end

  @impl true
  def handle_event("load_more", _params, socket) do
    next_page = socket.assigns.page + 1
    new_posts = Posts.list_user_posts(socket.assigns.profile_user.id, next_page)

    {:noreply,
     socket
     |> assign(:page, next_page)
     |> assign(:has_more?, length(new_posts) == 25)
     |> assign(:posts, socket.assigns.posts ++ new_posts)}
  end

  def handle_event("vote", %{"id" => post_id, "value" => value}, socket) do
    case socket.assigns.current_user do
      nil ->
        {:noreply, socket |> put_flash(:error, "投票するにはログインが必要です") |> redirect(to: "/login")}

      user ->
        case Posts.vote_post(user.id, post_id, String.to_integer(value)) do
          {:ok, updated_post} ->
            posts = Enum.map(socket.assigns.posts, fn post ->
              if post.id == updated_post.id, do: updated_post, else: post
            end)
            {:noreply, assign(socket, :posts, posts)}

          {:error, :cannot_vote_own_post} ->
            {:noreply, put_flash(socket, :error, "自分の投稿には投票できません")}
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto px-4 py-6">

      <div class="bg-white border border-gray-200 rounded p-6 mb-4">
        <h1 class="text-2xl font-bold text-gray-900">u/<%= @profile_user.username %></h1>
        <p class="text-sm text-gray-400 mt-1">
          <%= joined_at(@profile_user.inserted_at) %> に登録
        </p>

        <div class="flex gap-6 mt-4 pt-4 border-t border-gray-100">
          <div class="text-center">
            <p class="text-xl font-bold"><%= format_karma(@profile_user.post_karma) %></p>
            <p class="text-xs text-gray-400">Post Karma</p>
          </div>
          <div class="text-center">
            <p class="text-xl font-bold"><%= format_karma(@profile_user.comment_karma) %></p>
            <p class="text-xs text-gray-400">Comment Karma</p>
          </div>
          <div class="text-center">
            <p class="text-xl font-bold">
              <%= format_karma(@profile_user.post_karma + @profile_user.comment_karma) %>
            </p>
            <p class="text-xs text-gray-400">合計 Karma</p>
          </div>
        </div>
      </div>

      <h2 class="text-sm font-bold text-gray-500 uppercase mb-3">投稿</h2>

      <%= if @posts == [] do %>
        <div class="bg-white border border-gray-200 rounded p-8 text-center">
          <p class="text-gray-400 text-sm">まだ投稿がありません</p>
        </div>
      <% else %>
        <%= for post <- @posts do %>
          <.post_card post={post} show_subreddit={true} current_user={@current_user} />
        <% end %>

        <%= if @has_more? do %>
          <div class="text-center py-4">
            <button phx-click="load_more"
              class="px-6 py-2 border border-gray-300 rounded text-sm text-gray-600 hover:bg-gray-50">
              もっと見る
            </button>
          </div>
        <% end %>
      <% end %>

    </div>
    """
  end

  defp format_karma(karma) when karma >= 1000,
    do: "#{Float.round(karma / 1000, 1)}k"
  defp format_karma(karma), do: to_string(karma)

  defp joined_at(datetime),
    do: "#{datetime.year}年#{datetime.month}月"
end
```

**解説**

`profile_user` と `current_user` は別の変数です。

```elixir
assign(:profile_user, profile_user)  # 表示対象のユーザー
# current_user は on_mount で自動的にセット済み
```

自分のプロフィールを見ているとき両方が同じユーザーになりますが、他人のプロフィールを見ているときは異なります。混同しないように変数名を分けています。

---

## 6-8　SearchLive

```elixir
# lib/reddit_clone_web/live/search_live.ex
defmodule RedditCloneWeb.SearchLive do
  use RedditCloneWeb, :live_view

  import RedditCloneWeb.Components.PostCard

  alias RedditClone.Posts
  alias RedditClone.Communities

  on_mount {RedditCloneWeb.UserAuth, :fetch_current_user}

  @impl true
  def mount(%{"q" => query}, _session, socket) when query != "" do
    {:ok,
     socket
     |> assign(:page_title, "「#{query}」の検索結果")
     |> assign(:query, query)
     |> assign(:posts, Posts.search_posts(query))
     |> assign(:subreddits, Communities.search_subreddits(query))}
  end

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "検索")
     |> assign(:query, "")
     |> assign(:posts, [])
     |> assign(:subreddits, [])}
  end

  @impl true
  def handle_event("vote", %{"id" => post_id, "value" => value}, socket) do
    case socket.assigns.current_user do
      nil ->
        {:noreply, socket |> put_flash(:error, "投票するにはログインが必要です") |> redirect(to: "/login")}

      user ->
        case Posts.vote_post(user.id, post_id, String.to_integer(value)) do
          {:ok, updated_post} ->
            posts = Enum.map(socket.assigns.posts, fn post ->
              if post.id == updated_post.id, do: updated_post, else: post
            end)
            {:noreply, assign(socket, :posts, posts)}

          {:error, :cannot_vote_own_post} ->
            {:noreply, put_flash(socket, :error, "自分の投稿には投票できません")}
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto px-4 py-6">

      <form action="/search" method="get" class="mb-6">
        <div class="flex gap-2">
          <input type="text" name="q" value={@query}
            placeholder="キーワードを入力..."
            class="flex-1 border border-gray-300 rounded px-4 py-2 text-sm focus:outline-none focus:border-blue-400"
            autofocus />
          <button type="submit"
            class="px-4 py-2 bg-blue-500 text-white text-sm rounded hover:bg-blue-600">
            検索
          </button>
        </div>
      </form>

      <%= if @query == "" do %>
        <p class="text-gray-400 text-center py-12">キーワードを入力して検索してください</p>
      <% else %>
        <h1 class="text-lg font-bold mb-4">「<%= @query %>」の検索結果</h1>

        <div class="flex gap-4">
          <div class="flex-1">
            <h2 class="text-sm font-bold text-gray-500 uppercase mb-3">
              投稿 <%= if @posts != [], do: "(#{length(@posts)}件)" %>
            </h2>

            <%= if @posts == [] do %>
              <div class="bg-white border border-gray-200 rounded p-6 text-center">
                <p class="text-gray-400 text-sm">投稿が見つかりませんでした</p>
              </div>
            <% else %>
              <%= for post <- @posts do %>
                <.post_card post={post} show_subreddit={true} current_user={@current_user} />
              <% end %>
            <% end %>
          </div>

          <div class="w-64 shrink-0">
            <h2 class="text-sm font-bold text-gray-500 uppercase mb-3">
              コミュニティ <%= if @subreddits != [], do: "(#{length(@subreddits)}件)" %>
            </h2>

            <%= if @subreddits == [] do %>
              <div class="bg-white border border-gray-200 rounded p-4 text-center">
                <p class="text-gray-400 text-sm">見つかりませんでした</p>
              </div>
            <% else %>
              <%= for subreddit <- @subreddits do %>
                <div class="bg-white border border-gray-200 rounded p-3 mb-2 hover:border-gray-400">
                  <.link navigate={~p"/r/#{subreddit.name}"} class="block">
                    <p class="font-medium text-sm">r/<%= subreddit.name %></p>
                    <%= if subreddit.description do %>
                      <p class="text-xs text-gray-400 mt-1 truncate">
                        <%= subreddit.description %>
                      </p>
                    <% end %>
                  </.link>
                </div>
              <% end %>
            <% end %>
          </div>
        </div>
      <% end %>

    </div>
    """
  end
end
```

**解説**

検索フォームは LiveView のフォーム（`phx-submit`）ではなく、通常の HTML フォームです。

```heex
<form action="/search" method="get">
  <input type="text" name="q" value={@query} />
</form>
```

検索を実行するたびに `/search?q=キーワード` という URL になります。URL にキーワードが含まれるため、検索結果のページをブックマークしたり共有したりできます。

`mount/3` は2つのパターンで定義しています。

```elixir
def mount(%{"q" => query}, ...) when query != "" do
  # キーワードあり → 検索して結果を表示
end

def mount(_params, ...) do
  # キーワードなし → 空の状態で表示
end
```

`when query != ""` のガード節で空のクエリを弾きます。

---

## まとめ

この章では以下を完了しました。

```
✅ LiveView のライフサイクル（mount / render / handle_event）
✅ SubredditLive（Feed・Join/Leave・投票・報告）
✅ NewSubredditLive（コミュニティ作成）
✅ NewPostLive（タブ切り替え・投稿作成）
✅ PostLive（コメント・返信・削除・報告）
✅ HomeFeedLive（ホーム Feed・サイドバー）
✅ ProfileLive（Karma 表示・投稿一覧）
✅ SearchLive（投稿・コミュニティ検索）
```

**この章の重要なポイント**

- `assigns` が変わると `render/1` が自動的に再実行される
- `owner_id` などはサーバー側でセットして改ざんを防ぐ
- ページネーションは `++` で追記して画面を維持する
- 保護されたページでは `nil` チェックを省略できる
- 検索フォームは通常の HTML フォームにして URL を活用する

次の章ではコンポーネントを実装します。`PostCard`・`CommentTree`・`ReportModal` の3つです。
