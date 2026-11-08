defmodule RedditCloneWeb.NewSubredditLive do
  use RedditCloneWeb, :live_view

  alias RedditClone.Communities
  alias RedditClone.Communities.Subreddit

  on_mount {RedditCloneWeb.UserAuth, :require_auth}

  # ----------------------------------------------------------------
  # mount
  # ----------------------------------------------------------------

  @impl true
  def mount(_params, _session, socket) do
    changeset = Subreddit.changeset(%Subreddit{}, %{})

    {:ok,
     socket
     |> assign(:page_title, "コミュニティを作成")
     |> assign_form(changeset)}
  end

  # ----------------------------------------------------------------
  # イベント処理
  # ----------------------------------------------------------------

  @impl true
  def handle_event("validate", %{"subreddit" => params}, socket) do
    changeset =
      %Subreddit{}
      |> Subreddit.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("create", %{"subreddit" => params}, socket) do
    attrs = Map.put(params, "owner_id", socket.assigns.current_user.id)

    case Communities.create_subreddit(attrs) do
      {:ok, subreddit} ->
        {:noreply,
         socket
         |> put_flash(:info, "r/#{subreddit.name} を作成しました！")
         |> redirect(to: ~p"/r/#{subreddit.name}")}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  # ----------------------------------------------------------------
  # レンダリング
  # ----------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-lg mx-auto mt-12 px-4">
      <h1 class="text-2xl font-bold mb-6">コミュニティを作成</h1>

      <.form
        for={@form}
        phx-change="validate"
        phx-submit="create"
        class="bg-white border border-gray-200 rounded p-6"
      >

        <%!-- コミュニティ名 --%>
        <div class="mb-4">
          <.input
            field={@form[:name]}
            label="コミュニティ名"
            placeholder="例: elixir"
          />
          <p class="text-xs text-gray-400 mt-1">
            r/<%= if @form[:name].value != "", do: @form[:name].value, else: "○○" %>
            ・英数字とアンダースコアのみ・3〜21文字
          </p>
        </div>

        <%!-- 説明 --%>
        <div class="mb-6">
          <.input
            field={@form[:description]}
            type="textarea"
            label="説明（任意）"
            placeholder="このコミュニティは何について話す場所ですか？"
            rows="3"
          />
        </div>

        <.button type="submit" class="w-full">
          コミュニティを作成する
        </.button>

      </.form>
    </div>
    """
  end

  # ----------------------------------------------------------------
  # ヘルパー
  # ----------------------------------------------------------------

  defp assign_form(socket, changeset) do
    assign(socket, :form, to_form(changeset, as: "subreddit"))
  end
end
