defmodule RedditCloneWeb.Components.ReportModal do
  @moduledoc """
  投稿・コメントへの報告モーダル。
  SubredditLive / PostLive / HomeFeedLive / ProfileLive / SearchLive から使う。
  """

  use RedditCloneWeb, :html

  @reasons [
    {"spam",           "スパム"},
    {"harassment",     "嫌がらせ・ハラスメント"},
    {"hate_speech",    "ヘイトスピーチ"},
    {"misinformation", "誤情報"},
    {"other",          "その他"}
  ]

  @doc """
  報告モーダルを表示する。

  ## 属性
    - report_modal: %{target_type: "post"|"comment", target_id: id} | nil
  """
  attr :report_modal, :map, default: nil

  def report_modal(assigns) do
    assigns = assign(assigns, :reasons, @reasons)

    ~H"""
    <%= if @report_modal do %>
      <%!-- 背景オーバーレイ --%>
      <div
        class="fixed inset-0 bg-black bg-opacity-50 z-40"
        phx-click="close_report_modal"
      />

      <%!-- モーダル本体 --%>
      <div class="fixed inset-0 z-50 flex items-center justify-center p-4">
        <div class="bg-white rounded-lg shadow-xl w-full max-w-md">

          <%!-- ヘッダー --%>
          <div class="flex justify-between items-center p-4 border-b border-gray-200">
            <h2 class="text-lg font-bold">報告する</h2>
            <button
              phx-click="close_report_modal"
              class="text-gray-400 hover:text-gray-600 text-xl"
            >
              ✕
            </button>
          </div>

          <%!-- 理由の選択 --%>
          <div class="p-4">
            <p class="text-sm text-gray-600 mb-3">
              報告する理由を選択してください
            </p>

            <div class="space-y-2">
              <%= for {value, label} <- @reasons do %>
                <button
                  phx-click="submit_report"
                  phx-value-reason={value}
                  phx-value-target_type={@report_modal.target_type}
                  phx-value-target_id={@report_modal.target_id}
                  class="w-full text-left px-4 py-3 rounded border border-gray-200 text-sm hover:bg-gray-50 hover:border-gray-300 transition-colors"
                >
                  <%= label %>
                </button>
              <% end %>
            </div>
          </div>

          <%!-- フッター --%>
          <div class="p-4 border-t border-gray-100">
            <button
              phx-click="close_report_modal"
              class="w-full py-2 text-sm text-gray-500 hover:text-gray-700"
            >
              キャンセル
            </button>
          </div>

        </div>
      </div>
    <% end %>
    """
  end
end
