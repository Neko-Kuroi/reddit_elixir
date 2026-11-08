defmodule RedditCloneWeb.Components.CommentTree do
  @moduledoc """
  コメントをネスト構造で再帰的に表示するコンポーネント。
  PostLive から使う。
  """

  use RedditCloneWeb, :html

  import RedditCloneWeb.Helpers

  @max_depth 8

  @doc """
  コメントツリーを表示する。

  ## 属性
    - comments:     表示するコメントのリスト（ツリー構造）
    - current_user: ログイン中のユーザー（nil可）
    - depth:        現在のネスト深さ（デフォルト0）
  """
  attr :comments,     :list,  required: true
  attr :current_user, :map,   default: nil
  attr :depth,        :integer, default: 0

  def comment_tree(assigns) do
    ~H"""
    <div class={depth_class(@depth)}>
      <%= for comment <- @comments do %>
        <.comment_item
          comment={comment}
          current_user={@current_user}
          depth={@depth}
        />
      <% end %>
    </div>
    """
  end

  # 1件のコメントと、その子コメントを表示する
  attr :comment,      :map,     required: true
  attr :current_user, :map,     default: nil
  attr :depth,        :integer, default: 0

  defp comment_item(assigns) do
    ~H"""
    <div class="mb-2">
      <%!-- コメント本体 --%>
      <div class="flex gap-2">

        <%!-- 投票ボタン --%>
        <div class="flex flex-col items-center gap-0.5 pt-1">
          <button
            phx-click="vote_comment"
            phx-value-id={@comment.id}
            phx-value-value="1"
            class="text-gray-300 hover:text-orange-500 text-xs"
          >
            ▲
          </button>
          <span class="text-xs text-gray-500"><%= @comment.score %></span>
          <button
            phx-click="vote_comment"
            phx-value-id={@comment.id}
            phx-value-value="-1"
            class="text-gray-300 hover:text-blue-500 text-xs"
          >
            ▼
          </button>
        </div>

        <%!-- コメント内容 --%>
        <div class="flex-1 border-l-2 border-gray-100 pl-2">

          <%!-- メタ情報 --%>
          <div class="text-xs text-gray-500 mb-1">
            <span class="font-medium text-gray-700">
              u/<%= @comment.author.username %>
            </span>
            • <%= time_ago(@comment.inserted_at) %>
            • <%= @comment.score %> ポイント
          </div>

          <%!-- 本文 --%>
          <p class="text-sm text-gray-800 whitespace-pre-wrap"><%= @comment.body %></p>

          <%!-- アクションボタン --%>
          <div class="flex gap-3 mt-1">
            <%= if @current_user do %>
              <button
                phx-click="reply_to"
                phx-value-id={@comment.id}
                class="text-xs text-gray-400 hover:text-gray-600"
              >
                返信
              </button>
            <% end %>

            <%= if can_delete?(@current_user, @comment) do %>
              <button
                phx-click="delete_comment"
                phx-value-id={@comment.id}
                data-confirm="このコメントを削除しますか？"
                class="text-xs text-red-400 hover:text-red-600"
              >
                削除
              </button>
            <% end %>

            <%= if can_report?(@current_user, @comment) do %>
              <button
                phx-click="open_report_modal"
                phx-value-type="comment"
                phx-value-id={@comment.id}
                class="text-xs text-gray-400 hover:text-gray-600"
              >
                報告
              </button>
            <% end %>
          </div>

        </div>
      </div>

      <%!-- 子コメント（再帰）--%>
      <%= if @comment.replies != [] && @depth < @max_depth do %>
        <div class="ml-6 mt-1">
          <.comment_tree
            comments={@comment.replies}
            current_user={@current_user}
            depth={@depth + 1}
          />
        </div>
      <% end %>

    </div>
    """
  end

  # 深さに応じてインデントを調整する
  defp depth_class(0), do: ""
  defp depth_class(_), do: "border-l border-gray-200 pl-2"

  # 自分のコメントのみ削除できる
  defp can_delete?(nil, _comment), do: false
  defp can_delete?(user, comment),  do: user.id == comment.author_id

  # 自分のコメント以外を報告できる（ログイン必須）
  defp can_report?(nil, _comment), do: false
  defp can_report?(user, comment),  do: user.id != comment.author_id
end
