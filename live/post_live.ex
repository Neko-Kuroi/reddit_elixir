defmodule RedditCloneWeb.PostLive do
  use RedditCloneWeb, :live_view

  import RedditCloneWeb.Components.CommentTree
  import RedditCloneWeb.Components.ReportModal

  alias RedditClone.Posts
  alias RedditClone.Comments
  alias RedditClone.Comments.Comment
  alias RedditClone.Reports

  on_mount {RedditCloneWeb.UserAuth, :fetch_current_user}

  # ----------------------------------------------------------------
  # mount
  # ----------------------------------------------------------------

  @impl true
  def mount(%{"post_id" => post_id}, _session, socket) do
    case Posts.get_post(post_id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "投稿が見つかりません")
         |> redirect(to: "/")}

      post ->
        comments     = Comments.list_comments(post_id)
        comment_form = build_comment_form()

        {:ok,
         socket
         |> assign(:page_title, post.title)
         |> assign(:post, post)
         |> assign(:comments, comments)
         |> assign(:comment_form, comment_form)
         |> assign(:reply_to, nil)
         |> assign(:report_modal, nil)}
    end
  end

  # ----------------------------------------------------------------
  # イベント処理
  # ----------------------------------------------------------------

  @impl true

  # 投稿への投票
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
            {:noreply, assign(socket, :post, updated_post)}

          {:error, :cannot_vote_own_post} ->
            {:noreply, put_flash(socket, :error, "自分の投稿には投票できません")}
        end
    end
  end

  # コメントへの投票
  def handle_event("vote_comment", %{"id" => comment_id, "value" => value}, socket) do
    case socket.assigns.current_user do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "投票するにはログインが必要です")
         |> redirect(to: "/login")}

      user ->
        value = String.to_integer(value)

        case Comments.vote_comment(user.id, comment_id, value) do
          {:ok, _updated} ->
            # コメントツリーを再取得して更新
            comments = Comments.list_comments(socket.assigns.post.id)
            {:noreply, assign(socket, :comments, comments)}

          {:error, :cannot_vote_own_comment} ->
            {:noreply, put_flash(socket, :error, "自分のコメントには投票できません")}
        end
    end
  end

  # 返信ボタン → reply_to をセット
  def handle_event("reply_to", %{"id" => comment_id}, socket) do
    comment = Comments.get_comment!(comment_id)
    form    = build_comment_form(%{parent_id: comment_id})

    {:noreply,
     socket
     |> assign(:reply_to, comment)
     |> assign(:comment_form, form)}
  end

  # 返信キャンセル
  def handle_event("cancel_reply", _params, socket) do
    {:noreply,
     socket
     |> assign(:reply_to, nil)
     |> assign(:comment_form, build_comment_form())}
  end

  # コメント投稿
  def handle_event("create_comment", %{"comment" => params}, socket) do
    case socket.assigns.current_user do
      nil ->
        {:noreply, redirect(socket, to: "/login")}

      user ->
        attrs =
          params
          |> Map.put("author_id", user.id)
          |> Map.put("post_id", socket.assigns.post.id)

        case Comments.create_comment(attrs) do
          {:ok, _comment} ->
            # コメント一覧を再取得
            comments = Comments.list_comments(socket.assigns.post.id)

            {:noreply,
             socket
             |> assign(:comments, comments)
             |> assign(:reply_to, nil)
             |> assign(:comment_form, build_comment_form())}

          {:error, changeset} ->
            {:noreply, assign(socket, :comment_form, to_form(changeset, as: "comment"))}
        end
    end
  end

  # コメント削除
  def handle_event("delete_comment", %{"id" => comment_id}, socket) do
    case socket.assigns.current_user do
      nil ->
        {:noreply, redirect(socket, to: "/login")}

      user ->
        Comments.delete_comment(comment_id, user.id, socket.assigns.post.subreddit_id)
        comments = Comments.list_comments(socket.assigns.post.id)
        {:noreply, assign(socket, :comments, comments)}
    end
  end

  # 投稿削除
  def handle_event("delete_post", _params, socket) do
    case socket.assigns.current_user do
      nil ->
        {:noreply, redirect(socket, to: "/login")}

      user ->
        post = socket.assigns.post

        case Posts.delete_post(post.id, user.id, post.subreddit) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, "投稿を削除しました")
             |> redirect(to: ~p"/r/#{post.subreddit.name}")}

          {:error, :unauthorized} ->
            {:noreply, put_flash(socket, :error, "削除する権限がありません")}
        end
    end
  end

  # ----------------------------------------------------------------
  # レンダリング
  # ----------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto px-4 py-4">

      <%!-- 投稿本体 --%>
      <div class="bg-white border border-gray-200 rounded p-4 mb-4">

        <%!-- 投票 + タイトル --%>
        <div class="flex gap-3">
          <div class="flex flex-col items-center gap-1">
            <button
              phx-click="vote"
              phx-value-id={@post.id}
              phx-value-value="1"
              class="text-gray-400 hover:text-orange-500"
            >
              ▲
            </button>
            <span class="text-sm font-bold"><%= @post.score %></span>
            <button
              phx-click="vote"
              phx-value-id={@post.id}
              phx-value-value="-1"
              class="text-gray-400 hover:text-blue-500"
            >
              ▼
            </button>
          </div>

          <div class="flex-1">
            <h1 class="text-xl font-bold text-gray-900 mb-1">
              <%= @post.title %>
            </h1>

            <%!-- メタ情報 --%>
            <div class="text-xs text-gray-500 mb-3 flex gap-2">
              <.link navigate={~p"/r/#{@post.subreddit.name}"} class="hover:underline font-medium">
                r/<%= @post.subreddit.name %>
              </.link>
              <span>•</span>
              <span>
                u/<.link navigate={~p"/u/#{@post.author.username}"} class="hover:underline">
                  <%= @post.author.username %>
                </.link>
              </span>
            </div>

            <%!-- 本文（テキスト投稿）--%>
            <%= if @post.type == "text" && @post.body do %>
              <p class="text-sm text-gray-800 whitespace-pre-wrap mb-3">
                <%= @post.body %>
              </p>
            <% end %>

            <%!-- URL（リンク投稿）--%>
            <%= if @post.type == "link" do %>
              <a
                href={@post.url}
                target="_blank"
                rel="noopener noreferrer"
                class="text-sm text-blue-500 hover:underline break-all"
              >
                <%= @post.url %> ↗
              </a>
            <% end %>

            <%!-- 削除ボタン（本人のみ）--%>
            <%= if @current_user && @current_user.id == @post.author_id do %>
              <button
                phx-click="delete_post"
                data-confirm="この投稿を削除しますか？"
                class="text-xs text-red-400 hover:text-red-600 mt-2"
              >
                削除
              </button>
            <% end %>
          </div>
        </div>
      </div>

      <%!-- コメント投稿フォーム --%>
      <%= if @current_user do %>
        <div class="bg-white border border-gray-200 rounded p-4 mb-4">

          <%= if @reply_to do %>
            <div class="text-xs text-gray-500 mb-2 flex justify-between">
              <span>u/<%= @reply_to.author.username %> への返信</span>
              <button phx-click="cancel_reply" class="hover:text-gray-700">
                キャンセル
              </button>
            </div>
          <% else %>
            <p class="text-sm font-medium mb-2">コメントを追加</p>
          <% end %>

          <.form for={@comment_form} phx-submit="create_comment">
            <input type="hidden" name="comment[parent_id]" value={@reply_to && @reply_to.id} />

            <textarea
              name="comment[body]"
              rows="4"
              placeholder="コメントを入力してください"
              class="w-full border border-gray-300 rounded p-2 text-sm resize-none focus:outline-none focus:border-blue-400"
            ></textarea>

            <div class="flex justify-end mt-2">
              <.button type="submit" class="text-sm px-4 py-1">
                投稿する
              </.button>
            </div>
          </.form>
        </div>
      <% end %>

      <%!-- コメント一覧 --%>
      <div class="bg-white border border-gray-200 rounded p-4">
        <%= if @comments == [] do %>
          <p class="text-gray-400 text-sm text-center py-4">
            まだコメントはありません。最初のコメントを投稿しましょう！
          </p>
        <% else %>
          <.comment_tree
            comments={@comments}
            current_user={@current_user}
          />
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

  defp build_comment_form(attrs \\ %{}) do
    %Comment{}
    |> Comment.changeset(attrs)
    |> to_form(as: "comment")
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

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(:report_modal, nil)
         |> put_flash(:error, "報告に失敗しました。もう一度お試しください。")}
    end
  end
end
