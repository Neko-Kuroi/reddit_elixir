defmodule RedditCloneWeb.SubredditLive do
  use RedditCloneWeb, :live_view

  import RedditCloneWeb.Components.PostCard
  import RedditCloneWeb.Components.ReportModal

  alias RedditClone.Communities
  alias RedditClone.Posts
  alias RedditClone.Reports

  on_mount {RedditCloneWeb.UserAuth, :fetch_current_user}

  # ----------------------------------------------------------------
  # mount: 初回データ取得
  # ----------------------------------------------------------------

  @impl true
  def mount(%{"name" => name}, _session, socket) do
    case Communities.get_subreddit_by_name(name) do
      nil ->
        # Subredditが存在しない場合
        {:ok,
         socket
         |> put_flash(:error, "r/#{name} は存在しません")
         |> redirect(to: "/")}

      subreddit ->
        posts   = Posts.list_posts(subreddit.id, "hot", 1)
        joined? = joined?(socket.assigns.current_user, subreddit.id)

        {:ok,
         socket
         |> assign(:page_title, "r/#{subreddit.name}")
         |> assign(:subreddit, subreddit)
         |> assign(:posts, posts)
         |> assign(:sort, "hot")
         |> assign(:page, 1)
         |> assign(:has_more?, length(posts) == 25)
         |> assign(:report_modal, nil)
         |> assign(:joined?, joined?)}
    end
  end

  # ----------------------------------------------------------------
  # イベント処理
  # ----------------------------------------------------------------

  @impl true
  def handle_event("sort", %{"value" => sort}, socket) do
    # ソート切り替え時はページを1に戻す
    posts = Posts.list_posts(socket.assigns.subreddit.id, sort, 1)

    {:noreply,
     socket
     |> assign(:sort, sort)
     |> assign(:page, 1)
     |> assign(:has_more?, length(posts) == 25)
     |> assign(:posts, posts)}
  end

  def handle_event("join", _params, socket) do
    case socket.assigns.current_user do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "参加するにはログインが必要です")
         |> redirect(to: "/login")}

      user ->
        case Communities.join_subreddit(user.id, socket.assigns.subreddit.id) do
          {:ok, _member} ->
            {:noreply, assign(socket, :joined?, true)}

          {:error, _changeset} ->
            # 登録できなかった場合（すでに参加済みなど）は、実際の参加状態に合わせる
            {:noreply, assign(socket, :joined?, joined?(user, socket.assigns.subreddit.id))}
        end
    end
  end

  def handle_event("leave", _params, socket) do
    case Communities.leave_subreddit(
           socket.assigns.current_user.id,
           socket.assigns.subreddit.id
         ) do
      {:ok, _} ->
        {:noreply, assign(socket, :joined?, false)}

      {:error, :owner_cannot_leave} ->
        {:noreply, put_flash(socket, :error, "作成者はコミュニティを脱退できません")}
    end
  end

  def handle_event("load_more", _params, socket) do
    next_page  = socket.assigns.page + 1
    new_posts  = Posts.list_posts(socket.assigns.subreddit.id, socket.assigns.sort, next_page)

    {:noreply,
     socket
     |> assign(:page, next_page)
     |> assign(:has_more?, length(new_posts) == 25)
     |> assign(:posts, socket.assigns.posts ++ new_posts)}  # 既存に追記
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
            # 該当の投稿だけスコアを更新する
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
    <div class="max-w-4xl mx-auto px-4 py-4 flex gap-4">

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
          <p class="text-gray-500 text-center py-8">まだ投稿がありません</p>
        <% else %>
          <%= for post <- @posts do %>
            <.post_card
              post={post}
              show_subreddit={false}
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

      <%!-- サイドバー --%>
      <div class="w-72 shrink-0">
        <div class="bg-white border border-gray-200 rounded p-4">

          <h2 class="font-bold text-lg mb-2">r/<%= @subreddit.name %></h2>

          <%= if @subreddit.description do %>
            <p class="text-sm text-gray-600 mb-4"><%= @subreddit.description %></p>
          <% end %>

          <%!-- Join / Leave ボタン --%>
          <%= if @current_user do %>
            <%= if @joined? do %>
              <button
                phx-click="leave"
                class="w-full border border-blue-500 text-blue-500 rounded-full py-1 text-sm hover:bg-blue-50"
              >
                参加中
              </button>
            <% else %>
              <button
                phx-click="join"
                class="w-full bg-blue-500 text-white rounded-full py-1 text-sm hover:bg-blue-600"
              >
                参加する
              </button>
            <% end %>
          <% end %>

          <%!-- 投稿するボタン --%>
          <%= if @current_user do %>
            <.link
              navigate={~p"/r/#{@subreddit.name}/submit"}
              class="block w-full mt-2 border border-gray-300 text-center rounded-full py-1 text-sm hover:bg-gray-50"
            >
              投稿する
            </.link>
          <% end %>

        </div>
      </div>

    </div>

    <%!-- 報告モーダル --%>
    <.report_modal report_modal={@report_modal} />
    """
  end

  # ----------------------------------------------------------------
  # ヘルパー
  # ----------------------------------------------------------------

  defp joined?(nil, _subreddit_id), do: false
  defp joined?(user, subreddit_id),  do: Communities.member?(user.id, subreddit_id)

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
      "reporter_id"  => socket.assigns.current_user.id,
      "target_type"  => params["target_type"],
      "target_id"    => params["target_id"],
      "reason"       => params["reason"]
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
