# 第6章　画面実装（LiveView）後編

---

## 6-6　HomeFeedLive

HomeFeedLive はログイン済みユーザーのホームページです。Join 済みコミュニティの投稿を Hot/New 順で表示します。

```elixir
# lib/reddit_clone_web/live/home_feed_live.ex
defmodule RedditCloneWeb.HomeFeedLive do
  use RedditCloneWeb, :live_view

  import RedditCloneWeb.Components.PostCard
  import RedditCloneWeb.Components.ReportModal

  alias RedditClone.Communities
  alias RedditClone.Posts
  alias RedditClone.Reports

  on_mount {RedditCloneWeb.UserAuth, :require_auth}

  # ----------------------------------------------------------------
  # mount
  # ----------------------------------------------------------------

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    posts            = Posts.list_home_posts(user.id, "hot", 1)
    joined_subreddits = Communities.list_joined_subreddits(user.id)

    {:ok,
     socket
     |> assign(:page_title, "ホーム")
     |> assign(:posts, posts)
     |> assign(:sort, "hot")
     |> assign(:page, 1)
     |> assign(:has_more?, length(posts) == 25)
     |> assign(:joined_subreddits, joined_subreddits)
     |> assign(:report_modal, nil)}
  end

  # ----------------------------------------------------------------
  # イベント処理
  # ----------------------------------------------------------------

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
    value = String.to_integer(value)

    case Posts.vote_post(socket.assigns.current_user.id, post_id, value) do
      {:ok, updated_post} ->
        posts =
          Enum.map(socket.assigns.posts, fn post ->
            if post.id == updated_post.id, do: updated_post, else: post
          end)

        {:noreply, assign(socket, :posts, posts)}

      {:error, :cannot_vote_own_post} ->
        {:noreply, put_flash(socket, :error, "自分の投稿には投票できません")}
    end
  end

  # ----------------------------------------------------------------
  # レンダリング
  # ----------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto px-4 py-4 flex gap-4">

      <%!-- 左サイドバー: 参加中のSubreddit一覧 --%>
      <div class="w-48 shrink-0">
        <div class="bg-white border border-gray-200 rounded p-3">
          <h2 class="text-xs font-bold text-gray-500 uppercase mb-2">参加中</h2>

          <%= if @joined_subreddits == [] do %>
            <p class="text-xs text-gray-400">まだ参加していません</p>
          <% else %>
            <%= for subreddit <- @joined_subreddits do %>
              <.link
                navigate={~p"/r/#{subreddit.name}"}
                class="block text-sm py-1 hover:text-blue-500 truncate"
              >
                r/<%= subreddit.name %>
              </.link>
            <% end %>
          <% end %>

          <div class="border-t border-gray-100 mt-3 pt-3">
            <.link
              navigate={~p"/subreddits/new"}
              class="text-sm text-blue-500 hover:underline"
            >
              ＋ コミュニティを作成
            </.link>
          </div>
        </div>
      </div>

      <%!-- メインカラム --%>
      <div class="flex-1">

        <%!-- ソートタブ --%>
        <div class="bg-white border border-gray-200 rounded p-2 mb-4 flex gap-2">
          <button
            phx-click="sort"
            phx-value-value="hot"
            class={tab_class(@sort, "hot")}
          >
            🔥 Hot
          </button>
          <button
            phx-click="sort"
            phx-value-value="new"
            class={tab_class(@sort, "new")}
          >
            ✨ New
          </button>
        </div>

        <%!-- 投稿一覧 --%>
        <%= if @posts == [] do %>
          <div class="bg-white border border-gray-200 rounded p-8 text-center">
            <p class="text-gray-500 mb-2">まだ投稿がありません</p>
            <p class="text-sm text-gray-400">
              コミュニティに参加して投稿を見てみましょう
            </p>
            <.link
              navigate={~p"/subreddits/new"}
              class="inline-block mt-4 px-4 py-2 bg-blue-500 text-white text-sm rounded hover:bg-blue-600"
            >
              コミュニティを探す
            </.link>
          </div>
        <% else %>
          <%= for post <- @posts do %>
            <.post_card
              post={post}
              show_subreddit={true}
              current_user={@current_user}
            />
          <% end %>

          <%!-- もっと見るボタン --%>
          <%= if @has_more? do %>
            <div class="text-center py-4">
              <button
                phx-click="load_more"
                class="px-6 py-2 border border-gray-300 rounded text-sm text-gray-600 hover:bg-gray-50"
              >
                もっと見る
              </button>
            </div>
          <% end %>
        <% end %>

      </div>

    </div>

    <%!-- 報告モーダル --%>
    <.report_modal report_modal={@report_modal} />
    """
  end

  # ----------------------------------------------------------------
  # ヘルパー
  # ----------------------------------------------------------------

  defp tab_class(current, tab) when current == tab do
    "px-4 py-1 rounded bg-gray-200 font-bold text-sm"
  end
  defp tab_class(_, _) do
    "px-4 py-1 rounded hover:bg-gray-100 text-sm text-gray-600"
  end

  # 報告モーダルを開く
  def handle_event("open_report_modal", %{"type" => type, "id" => id}, socket) do
    case socket.assigns.current_user do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "報告するにはログインが必要です")
         |> redirect(to: "/login")}

      _ ->
        {:noreply, assign(socket, :report_modal, %{target_type: type, target_id: id})}
    end
  end

  # 報告モーダルを閉じる
  def handle_event("close_report_modal", _params, socket) do
    {:noreply, assign(socket, :report_modal, nil)}
  end

  # 報告を送信する
  def handle_event("submit_report", params, socket) do
    attrs = %{
      "reporter_id" => socket.assigns.current_user.id,
      "target_type" => params["target_type"],
      "target_id"   => params["target_id"],
      "reason"      => params["reason"]
    }

    case Reports.create_report(attrs) do
      {:ok, _report} ->
        {:noreply,
         socket
         |> assign(:report_modal, nil)
         |> put_flash(:info, "報告しました。ご協力ありがとうございます。")}

      {:error, :cannot_report_own_content} ->
        {:noreply,
         socket
         |> assign(:report_modal, nil)
         |> put_flash(:error, "自分のコンテンツは報告できません")}

      {:error, :target_not_found} ->
        {:noreply,
         socket
         |> assign(:report_modal, nil)
         |> put_flash(:error, "報告対象が見つかりませんでした")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(:report_modal, nil)
         |> put_flash(:error, "報告に失敗しました。もう一度お試しください。")}
    end
  end
end
```

**読み解き**

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

この画面にも、報告の3点セットが入っています（mount での初期化、render 末尾の `<.report_modal>`、ファイル末尾の3つのハンドラ）。理由は単純で、この画面は PostCard を使って投稿を表示するからです。PostCard の「報告」ボタンは `open_report_modal` というイベントを送りますが、それを受け取るのは「その部品を表示している LiveView」です。受け手の無い画面にボタンを置くと、押したときにイベントの行き先が無くなります。ですので、PostCard を使う画面では必ずこの3点セットをそろえます（部品と画面の分担については、第7章で改めて扱います）。

なお、`open_report_modal` の中では未ログインのチェックをしています。この画面は `require_auth` で保護されているので、通常は未ログインのまま届くことはありません。3点セットは5画面で同じ形にそろえてあり、チェックが二重になっていても害はありません。

---

## 6-7　ProfileLive

ProfileLive はユーザーのプロフィールページです。そのユーザーの情報と Karma、投稿の一覧を表示します。

```elixir
# lib/reddit_clone_web/live/profile_live.ex
defmodule RedditCloneWeb.ProfileLive do
  use RedditCloneWeb, :live_view

  import RedditCloneWeb.Components.PostCard
  import RedditCloneWeb.Components.ReportModal

  alias RedditClone.Accounts
  alias RedditClone.Posts
  alias RedditClone.Reports

  on_mount {RedditCloneWeb.UserAuth, :fetch_current_user}

  # ----------------------------------------------------------------
  # mount
  # ----------------------------------------------------------------

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
         |> assign(:has_more?, length(posts) == 25)
         |> assign(:report_modal, nil)}
    end
  end

  # ----------------------------------------------------------------
  # イベント処理
  # ----------------------------------------------------------------

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
        {:noreply,
         socket
         |> put_flash(:error, "投票するにはログインが必要です")
         |> redirect(to: "/login")}

      user ->
        value = String.to_integer(value)

        case Posts.vote_post(user.id, post_id, value) do
          {:ok, updated_post} ->
            posts =
              Enum.map(socket.assigns.posts, fn post ->
                if post.id == updated_post.id, do: updated_post, else: post
              end)

            {:noreply, assign(socket, :posts, posts)}

          {:error, :cannot_vote_own_post} ->
            {:noreply, put_flash(socket, :error, "自分の投稿には投票できません")}
        end
    end
  end

  # ----------------------------------------------------------------
  # レンダリング
  # ----------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto px-4 py-6">

      <%!-- ユーザー情報カード --%>
      <div class="bg-white border border-gray-200 rounded p-6 mb-4">

        <div class="flex items-start justify-between">
          <div>
            <h1 class="text-2xl font-bold text-gray-900">
              u/<%= @profile_user.username %>
            </h1>
            <p class="text-sm text-gray-400 mt-1">
              <%= joined_at(@profile_user.inserted_at) %> に登録
            </p>
          </div>
        </div>

        <%!-- Karma --%>
        <div class="flex gap-6 mt-4 pt-4 border-t border-gray-100">
          <div class="text-center">
            <p class="text-xl font-bold text-gray-800">
              <%= format_karma(@profile_user.post_karma) %>
            </p>
            <p class="text-xs text-gray-400">Post Karma</p>
          </div>
          <div class="text-center">
            <p class="text-xl font-bold text-gray-800">
              <%= format_karma(@profile_user.comment_karma) %>
            </p>
            <p class="text-xs text-gray-400">Comment Karma</p>
          </div>
          <div class="text-center">
            <p class="text-xl font-bold text-gray-800">
              <%= format_karma(@profile_user.post_karma + @profile_user.comment_karma) %>
            </p>
            <p class="text-xs text-gray-400">合計 Karma</p>
          </div>
        </div>

      </div>

      <%!-- 投稿一覧 --%>
      <h2 class="text-sm font-bold text-gray-500 uppercase mb-3">投稿</h2>

      <%= if @posts == [] do %>
        <div class="bg-white border border-gray-200 rounded p-8 text-center">
          <p class="text-gray-400 text-sm">まだ投稿がありません</p>
        </div>
      <% else %>
        <%= for post <- @posts do %>
          <.post_card
            post={post}
            show_subreddit={true}
            current_user={@current_user}
          />
        <% end %>

        <%!-- もっと見るボタン --%>
        <%= if @has_more? do %>
          <div class="text-center py-4">
            <button
              phx-click="load_more"
              class="px-6 py-2 border border-gray-300 rounded text-sm text-gray-600 hover:bg-gray-50"
            >
              もっと見る
            </button>
          </div>
        <% end %>
      <% end %>

    </div>

    <%!-- 報告モーダル --%>
    <.report_modal report_modal={@report_modal} />
    """
  end

  # ----------------------------------------------------------------
  # ヘルパー
  # ----------------------------------------------------------------

  # Karma を読みやすい形式にする（1000以上は k 表記）
  defp format_karma(karma) when karma >= 1000 do
    "#{Float.round(karma / 1000, 1)}k"
  end
  defp format_karma(karma), do: to_string(karma)

  # 登録日を「2024年1月」形式で表示する
  defp joined_at(datetime) do
    "#{datetime.year}年#{datetime.month}月"
  end

  # 報告モーダルを開く
  def handle_event("open_report_modal", %{"type" => type, "id" => id}, socket) do
    case socket.assigns.current_user do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "報告するにはログインが必要です")
         |> redirect(to: "/login")}

      _ ->
        {:noreply, assign(socket, :report_modal, %{target_type: type, target_id: id})}
    end
  end

  # 報告モーダルを閉じる
  def handle_event("close_report_modal", _params, socket) do
    {:noreply, assign(socket, :report_modal, nil)}
  end

  # 報告を送信する
  def handle_event("submit_report", params, socket) do
    attrs = %{
      "reporter_id" => socket.assigns.current_user.id,
      "target_type" => params["target_type"],
      "target_id"   => params["target_id"],
      "reason"      => params["reason"]
    }

    case Reports.create_report(attrs) do
      {:ok, _report} ->
        {:noreply,
         socket
         |> assign(:report_modal, nil)
         |> put_flash(:info, "報告しました。ご協力ありがとうございます。")}

      {:error, :cannot_report_own_content} ->
        {:noreply,
         socket
         |> assign(:report_modal, nil)
         |> put_flash(:error, "自分のコンテンツは報告できません")}

      {:error, :target_not_found} ->
        {:noreply,
         socket
         |> assign(:report_modal, nil)
         |> put_flash(:error, "報告対象が見つかりませんでした")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(:report_modal, nil)
         |> put_flash(:error, "報告に失敗しました。もう一度お試しください。")}
    end
  end
end
```

**読み解き**

`profile_user` と `current_user` は別の変数です。

```elixir
assign(:profile_user, profile_user)  # 表示対象のユーザー
# current_user は on_mount で自動的にセット済み
```

自分のプロフィールを見ているとき両方が同じユーザーになりますが、他人のプロフィールを見ているときは異なります。混同しないように変数名を分けています。

`format_karma/1` は、ガードを使った複数節です。`when karma >= 1000` の節が先に試され、1000以上なら小数1桁までの「k」表記（例: 1.2k）にします。第4章の投票処理と同じく、「条件で節を使い分ける」書き方が、表示の整形にも使われています。

この画面も PostCard を使うため、報告の3点セットを持っています。HomeFeedLive と違うのは、こちらは未ログインでも見られる画面（`fetch_current_user`）だという点です。そのため、`vote` と `open_report_modal` の両方で、未ログインならログイン画面へ誘導するチェックが入っています。

---

## 6-8　SearchLive

SearchLive は検索結果ページです。投稿とコミュニティを、キーワードで横断検索します。

```elixir
# lib/reddit_clone_web/live/search_live.ex
defmodule RedditCloneWeb.SearchLive do
  use RedditCloneWeb, :live_view

  import RedditCloneWeb.Components.PostCard
  import RedditCloneWeb.Components.ReportModal

  alias RedditClone.Posts
  alias RedditClone.Communities
  alias RedditClone.Reports

  on_mount {RedditCloneWeb.UserAuth, :fetch_current_user}

  # ----------------------------------------------------------------
  # mount
  # ----------------------------------------------------------------

  @impl true
  def mount(%{"q" => query}, _session, socket) when query != "" do
    posts      = Posts.search_posts(query)
    subreddits = Communities.search_subreddits(query)

    {:ok,
     socket
     |> assign(:page_title, "「#{query}」の検索結果")
     |> assign(:query, query)
     |> assign(:posts, posts)
     |> assign(:subreddits, subreddits)
     |> assign(:report_modal, nil)}
  end

  def mount(_params, _session, socket) do
    # クエリなしでアクセスした場合は空状態
    {:ok,
     socket
     |> assign(:page_title, "検索")
     |> assign(:query, "")
     |> assign(:posts, [])
     |> assign(:subreddits, [])
     |> assign(:report_modal, nil)}
  end

  # ----------------------------------------------------------------
  # イベント処理
  # ----------------------------------------------------------------

  @impl true
  def handle_event("vote", %{"id" => post_id, "value" => value}, socket) do
    case socket.assigns.current_user do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "投票するにはログインが必要です")
         |> redirect(to: "/login")}

      user ->
        value = String.to_integer(value)

        case Posts.vote_post(user.id, post_id, value) do
          {:ok, updated_post} ->
            posts =
              Enum.map(socket.assigns.posts, fn post ->
                if post.id == updated_post.id, do: updated_post, else: post
              end)

            {:noreply, assign(socket, :posts, posts)}

          {:error, :cannot_vote_own_post} ->
            {:noreply, put_flash(socket, :error, "自分の投稿には投票できません")}
        end
    end
  end

  # ----------------------------------------------------------------
  # レンダリング
  # ----------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto px-4 py-6">

      <%!-- 検索フォーム --%>
      <form action="/search" method="get" class="mb-6">
        <div class="flex gap-2">
          <input
            type="text"
            name="q"
            value={@query}
            placeholder="キーワードを入力..."
            class="flex-1 border border-gray-300 rounded px-4 py-2 text-sm focus:outline-none focus:border-blue-400"
            autofocus
          />
          <button
            type="submit"
            class="px-4 py-2 bg-blue-500 text-white text-sm rounded hover:bg-blue-600"
          >
            検索
          </button>
        </div>
      </form>

      <%= if @query == "" do %>
        <p class="text-gray-400 text-center py-12">
          キーワードを入力して検索してください
        </p>
      <% else %>
        <h1 class="text-lg font-bold mb-4">
          「<%= @query %>」の検索結果
        </h1>

        <div class="flex gap-4">

          <%!-- 左カラム: 投稿の検索結果 --%>
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
                <.post_card
                  post={post}
                  show_subreddit={true}
                  current_user={@current_user}
                />
              <% end %>
            <% end %>
          </div>

          <%!-- 右カラム: Subredditの検索結果 --%>
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

    <%!-- 報告モーダル --%>
    <.report_modal report_modal={@report_modal} />
    """
  end

  # 報告モーダルを開く
  def handle_event("open_report_modal", %{"type" => type, "id" => id}, socket) do
    case socket.assigns.current_user do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "報告するにはログインが必要です")
         |> redirect(to: "/login")}

      _ ->
        {:noreply, assign(socket, :report_modal, %{target_type: type, target_id: id})}
    end
  end

  # 報告モーダルを閉じる
  def handle_event("close_report_modal", _params, socket) do
    {:noreply, assign(socket, :report_modal, nil)}
  end

  # 報告を送信する
  def handle_event("submit_report", params, socket) do
    attrs = %{
      "reporter_id" => socket.assigns.current_user.id,
      "target_type" => params["target_type"],
      "target_id"   => params["target_id"],
      "reason"      => params["reason"]
    }

    case Reports.create_report(attrs) do
      {:ok, _report} ->
        {:noreply,
         socket
         |> assign(:report_modal, nil)
         |> put_flash(:info, "報告しました。ご協力ありがとうございます。")}

      {:error, :cannot_report_own_content} ->
        {:noreply,
         socket
         |> assign(:report_modal, nil)
         |> put_flash(:error, "自分のコンテンツは報告できません")}

      {:error, :target_not_found} ->
        {:noreply,
         socket
         |> assign(:report_modal, nil)
         |> put_flash(:error, "報告対象が見つかりませんでした")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(:report_modal, nil)
         |> put_flash(:error, "報告に失敗しました。もう一度お試しください。")}
    end
  end
end
```

**読み解き**

検索フォームは LiveView のフォーム（`phx-submit`）ではなく、通常の HTML フォームです。

```heex
<form action="/search" method="get">
  <input type="text" name="q" value={@query} />
</form>
```

検索を実行するたびに `/search?q=キーワード` という URL になります。URL にキーワードが含まれるため、検索結果のページをブックマークしたり共有したりできます。第8章で作るナビゲーションバーの検索フォームも、同じ URL を作ってこの画面に届けます。

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

検索の中身については、画面はキーワードを渡すだけです。投稿の検索は `Posts.search_posts/1`、コミュニティの検索は `Communities.search_subreddits/1`（どちらも第4章）に任せ、「何をヒットさせるか」のルールは Context 側に置きます。

この画面も PostCard を使うため報告の3点セットを持ちますが、1つ注意点があります。mount が2節あるので、**どちらの節でも** `assign(:report_modal, nil)` をしていることです。片方の節で初期化を忘れると、その入り方をしたときに、render がまだ無い assigns を読んでエラーになります。「render で使う assigns は、mount の全ての節で初期化する」が、この画面から得られる決まりです。

---

## 動作確認（この章の仕上げ）

前提: 第1〜5章が済み、`mix phx.server` でサーバーが起動できること（組み立てたプロジェクトの環境で確認します）。

- [ ] 未ログインの状態で `/r/elixir` を開ける。Join のボタンは出ず、投票ボタンを押すとログイン画面へ誘導される
- [ ] ログインして「参加する」を押すと「参加中」に変わり、「参加中」を押すと脱退できる。コミュニティの作成者本人は脱退できず、その旨のフラッシュメッセージが出る
- [ ] `/subreddits/new` でコミュニティを作成でき、作成直後にそのコミュニティページへ移動する。名前の入力中に、`r/○○` の形でプレビューが出る
- [ ] テキスト投稿とリンク投稿をタブで切り替えて、それぞれ作成できる。投稿後は詳細ページへ移動する
- [ ] 投稿詳細でコメントを投稿でき、「返信」を押すとフォームが返信用に変わり、返信が入れ子で表示される
- [ ] 投稿とコメントに投票するとスコアがその場で変わる。自分の投稿・コメントではエラーが表示される
- [ ] ホーム Feed（`/`）に参加中コミュニティの投稿が出て、Hot/New の切り替えと「もっと見る」が動く
- [ ] 他人の投稿の「報告」を押すとモーダルが開き、理由を選ぶと「報告しました」と表示される。これを、コミュニティページ・投稿詳細・ホーム Feed・プロフィール・検索結果の5画面すべてで確かめる
- [ ] プロフィール（`/u/ユーザー名`）で Karma が表示される
- [ ] `/search?q=キーワード` で投稿とコミュニティの両方がヒットする。キーワードなしで `/search` を開くと、空の案内が出る

---

## よくあるエラーと対処

| 症状 | 原因 | 直し方 |
|------|------|--------|
| 「報告」ボタンを押すと画面が落ちる・再読み込みされる | その LiveView に `handle_event("open_report_modal", ...)` の受け手が無い。イベントに対応する節が無いと、LiveView のプロセスがエラーで終了します | PostCard を使う画面には、開く・閉じる・送信の3ハンドラと、mount での `report_modal` 初期化、render での `<.report_modal>` 描画をそろえる（第7章でも扱います） |
| 投稿やコメントを削除すると `(UndefinedFunctionError) Communities.moderator?/2 is undefined` と出る | 削除の権限判定を Context が `Communities.moderator?/2` に聞くが、その関数が定義されていない | 第4章の `moderator?/2` が `communities.ex` に定義されているか確認する。本書の完成コードには定義済みです（これは、検証のときに実際に見つかった不整合の例です） |
| 画面で `(KeyError) key :report_modal not found` のような assigns のエラーが出る | mount で初期化していない assigns を、render で使っている | render で使う assigns は、mount で必ず初期値を入れる。mount が複数節ある画面（SearchLive）では、全ての節で入れる |
| フォームの入力エラーが表示されない | チェンジセットに action が付いていない | `validate` ハンドラで `Map.put(:action, :validate)` をする |
| 投票しても画面のスコアが変わらない | ハンドラで assigns を更新していない、または更新した投稿の差し替えをしていない | `{:ok, updated_post}` を受けて、対象の投稿だけを差し替える（SubredditLive の `vote`）か、一覧を取り直す（PostLive の `vote_comment`） |

---

## 確認問題

1. LiveView で assigns を更新すると、画面はどう変わりますか。ブラウザに送られるのは、ページ全体ですか、それとも一部ですか。
2. SubredditLive の mount で、存在しないコミュニティ名だった場合の処理の流れを説明してください。`put_flash` と `redirect` は、それぞれ何をしていますか。
3. HomeFeedLive の `vote` ハンドラには未ログインのチェックが無く、ProfileLive にはあります。なぜですか。
4. SearchLive の mount が2節ある理由と、どちらの節でも `report_modal` を初期化しなければならない理由を説明してください。
5. PostCard の「報告」ボタンを押したとき、イベントはどこに届きますか。モーダルが「開いているかどうか」の状態は、誰が持ちますか。

---

## まとめと次章へのつながり

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

- `assigns` が変わると `render/1` が自動的に再実行され、差分だけがブラウザに送られる
- `owner_id` などはサーバー側でセットして改ざんを防ぐ
- ページネーションは `++` で追記して画面を維持する
- 保護されたページでは `nil` チェックを省略できる
- 検索フォームは通常の HTML フォームにして URL を活用する
- PostCard を使う画面には、報告の3点セット（初期化・描画・3ハンドラ）を必ずそろえる

次の章ではコンポーネントを実装します。この章の画面が呼び出していた `PostCard`・`CommentTree`・`ReportModal` の3つの中身を作ります。

---

## 確認問題の答え

1. assigns が変わると `render/1` が再実行され、新しい HTML と前の HTML の差分だけがブラウザに送られて、その部分だけが書き換わります。ページ全体の送り直しはしません。
2. `Communities.get_subreddit_by_name/1` が `nil` を返す節に入り、まず `put_flash` で「r/○○ は存在しません」という通知を次の画面向けに入れ、続けて `redirect` でトップページへの移動を指示して、`{:ok, socket}` を返します。フラッシュは「遷移先に1回だけ出す通知」、redirect は「この画面の表示を取りやめて別ページへ移る指示」です。
3. HomeFeedLive は `on_mount` に `:require_auth` を指定していて、未ログインでは mount の前にログイン画面へ飛ばされるため、`current_user` が必ず存在します。ProfileLive は `:fetch_current_user` で誰でも見られる画面なので、未ログイン（`current_user` が `nil`）のまま操作が届くことがあり、ハンドラ側で確かめる必要があります。
4. キーワードの有無で初期状態が違うためです。`q` があって空でない場合は検索結果を持ち、無い場合は空の状態で始めます。そして render はどちらの入り方でも `@report_modal` を読むので、片方の節で初期化を忘れると、その入り方をしたときにエラーになります。
5. イベントは、その PostCard を表示している LiveView に届きます（部品自身は処理しません）。開閉の状態は画面側の assigns（`report_modal`）が持ち、部品はその値を見て描画するだけです。
