defmodule RedditCloneWeb.NewPostLive do
  use RedditCloneWeb, :live_view

  alias RedditClone.Communities
  alias RedditClone.Posts
  alias RedditClone.Posts.Post

  on_mount {RedditCloneWeb.UserAuth, :require_auth}

  # ----------------------------------------------------------------
  # mount
  # ----------------------------------------------------------------

  @impl true
  def mount(%{"name" => name}, _session, socket) do
    case Communities.get_subreddit_by_name(name) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "r/#{name} は存在しません")
         |> redirect(to: "/")}

      subreddit ->
        changeset = Post.changeset(%Post{}, %{type: "text"})

        {:ok,
         socket
         |> assign(:page_title, "r/#{subreddit.name} に投稿する")
         |> assign(:subreddit, subreddit)
         |> assign(:type, "text")
         |> assign_form(changeset)}
    end
  end

  # ----------------------------------------------------------------
  # イベント処理
  # ----------------------------------------------------------------

  @impl true
  def handle_event("switch_type", %{"type" => type}, socket) do
    # テキスト / リンク タブの切り替え
    changeset = Post.changeset(%Post{}, %{type: type})

    {:noreply,
     socket
     |> assign(:type, type)
     |> assign_form(changeset)}
  end

  def handle_event("validate", %{"post" => params}, socket) do
    changeset =
      %Post{}
      |> Post.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("create", %{"post" => params}, socket) do
    attrs =
      params
      |> Map.put("author_id", socket.assigns.current_user.id)
      |> Map.put("subreddit_id", socket.assigns.subreddit.id)

    case Posts.create_post(attrs) do
      {:ok, post} ->
        {:noreply,
         socket
         |> put_flash(:info, "投稿しました！")
         |> redirect(to: ~p"/r/#{socket.assigns.subreddit.name}/#{post.id}")}

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
    <div class="max-w-2xl mx-auto mt-8 px-4">
      <h1 class="text-xl font-bold mb-4">
        r/<%= @subreddit.name %> に投稿する
      </h1>

      <%!-- テキスト / リンク タブ --%>
      <div class="flex border-b border-gray-200 mb-4">
        <button
          phx-click="switch_type"
          phx-value-type="text"
          class={tab_class(@type, "text")}
        >
          📝 テキスト
        </button>
        <button
          phx-click="switch_type"
          phx-value-type="link"
          class={tab_class(@type, "link")}
        >
          🔗 リンク
        </button>
      </div>

      <.form
        for={@form}
        phx-change="validate"
        phx-submit="create"
        class="bg-white border border-gray-200 rounded p-4"
      >
        <%!-- type は hidden で送る --%>
        <input type="hidden" name="post[type]" value={@type} />

        <%!-- タイトル --%>
        <div class="mb-4">
          <.input
            field={@form[:title]}
            label="タイトル"
            placeholder="投稿のタイトルを入力してください"
          />
        </div>

        <%!-- テキスト投稿: 本文 --%>
        <%= if @type == "text" do %>
          <div class="mb-4">
            <.input
              field={@form[:body]}
              type="textarea"
              label="本文"
              placeholder="本文を入力してください（任意）"
              rows="6"
            />
          </div>
        <% end %>

        <%!-- リンク投稿: URL --%>
        <%= if @type == "link" do %>
          <div class="mb-4">
            <.input
              field={@form[:url]}
              type="url"
              label="URL"
              placeholder="https://example.com"
            />
          </div>
        <% end %>

        <div class="flex justify-end gap-2">
          <.link
            navigate={~p"/r/#{@subreddit.name}"}
            class="px-4 py-2 text-sm border border-gray-300 rounded hover:bg-gray-50"
          >
            キャンセル
          </.link>
          <.button type="submit">
            投稿する
          </.button>
        </div>

      </.form>
    </div>
    """
  end

  # ----------------------------------------------------------------
  # ヘルパー
  # ----------------------------------------------------------------

  defp assign_form(socket, changeset) do
    assign(socket, :form, to_form(changeset, as: "post"))
  end

  defp tab_class(current, tab) when current == tab do
    "px-6 py-2 text-sm font-bold border-b-2 border-blue-500 text-blue-500"
  end
  defp tab_class(_, _) do
    "px-6 py-2 text-sm text-gray-500 hover:text-gray-700"
  end
end
