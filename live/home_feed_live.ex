defmodule RedditCloneWeb.HomeFeedLive do
  use RedditCloneWeb, :live_view

  import RedditCloneWeb.Components.PostCard

  alias RedditClone.Communities
  alias RedditClone.Posts

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
     |> assign(:joined_subreddits, joined_subreddits)}
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
end
