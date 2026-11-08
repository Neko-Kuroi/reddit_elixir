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
