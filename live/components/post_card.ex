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
