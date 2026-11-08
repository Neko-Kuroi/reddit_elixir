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
