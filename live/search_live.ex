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
