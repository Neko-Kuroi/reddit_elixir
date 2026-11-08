# 第6章　画面実装（LiveView）中編

---

## 6-4　NewPostLive

NewPostLive は投稿作成ページです。テキスト投稿とリンク投稿をタブで切り替えます。

```elixir
# lib/reddit_clone_web/live/new_post_live.ex
defmodule RedditCloneWeb.NewPostLive do
  use RedditCloneWeb, :live_view

  alias RedditClone.Communities
  alias RedditClone.Posts
  alias RedditClone.Posts.Post

  on_mount {RedditCloneWeb.UserAuth, :require_auth}

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

  @impl true
  def handle_event("switch_type", %{"type" => type}, socket) do
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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto mt-8 px-4">
      <h1 class="text-xl font-bold mb-4">r/<%= @subreddit.name %> に投稿する</h1>

      <%!-- タブ切り替え --%>
      <div class="flex border-b border-gray-200 mb-4">
        <button phx-click="switch_type" phx-value-type="text" class={tab_class(@type, "text")}>
          📝 テキスト
        </button>
        <button phx-click="switch_type" phx-value-type="link" class={tab_class(@type, "link")}>
          🔗 リンク
        </button>
      </div>

      <.form for={@form} phx-change="validate" phx-submit="create"
        class="bg-white border border-gray-200 rounded p-4">

        <input type="hidden" name="post[type]" value={@type} />

        <div class="mb-4">
          <.input field={@form[:title]} label="タイトル"
            placeholder="投稿のタイトルを入力してください" />
        </div>

        <%= if @type == "text" do %>
          <div class="mb-4">
            <.input field={@form[:body]} type="textarea" label="本文" rows="6"
              placeholder="本文を入力してください（任意）" />
          </div>
        <% end %>

        <%= if @type == "link" do %>
          <div class="mb-4">
            <.input field={@form[:url]} type="url" label="URL"
              placeholder="https://example.com" />
          </div>
        <% end %>

        <div class="flex justify-end gap-2">
          <.link navigate={~p"/r/#{@subreddit.name}"}
            class="px-4 py-2 text-sm border border-gray-300 rounded hover:bg-gray-50">
            キャンセル
          </.link>
          <.button type="submit">投稿する</.button>
        </div>
      </.form>
    </div>
    """
  end

  defp assign_form(socket, changeset) do
    assign(socket, :form, to_form(changeset, as: "post"))
  end

  defp tab_class(current, tab) when current == tab,
    do: "px-6 py-2 text-sm font-bold border-b-2 border-blue-500 text-blue-500"
  defp tab_class(_, _),
    do: "px-6 py-2 text-sm text-gray-500 hover:text-gray-700"
end
```

**解説**

タブ切り替えは `assigns` の `:type` を変更するだけです。

```elixir
def handle_event("switch_type", %{"type" => type}, socket) do
  changeset = Post.changeset(%Post{}, %{type: type})  # フォームをリセット

  {:noreply,
   socket
   |> assign(:type, type)      # タブの状態を更新
   |> assign_form(changeset)}  # フォームを新しい type でリセット
end
```

タブを切り替えるとフォームをリセットします。テキスト欄に入力してからリンクタブに切り替えたとき、テキストの内容が残らないようにするためです。

`type` は hidden フィールドでフォームに含めます。

```heex
<input type="hidden" name="post[type]" value={@type} />
```

`phx-change="validate"` ではフォームの全フィールドが送られてくるため、hidden フィールドの `type` も一緒に渡されます。

---

## 6-5　PostLive

PostLive は投稿詳細ページです。投稿の表示・コメント投稿・返信・投票・削除・報告を担当します。

```elixir
# lib/reddit_clone_web/live/post_live.ex
defmodule RedditCloneWeb.PostLive do
  use RedditCloneWeb, :live_view

  import RedditCloneWeb.Components.CommentTree
  import RedditCloneWeb.Components.ReportModal

  alias RedditClone.Posts
  alias RedditClone.Comments
  alias RedditClone.Comments.Comment
  alias RedditClone.Reports

  on_mount {RedditCloneWeb.UserAuth, :fetch_current_user}

  @impl true
  def mount(%{"post_id" => post_id}, _session, socket) do
    case Posts.get_post(post_id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "投稿が見つかりません")
         |> redirect(to: "/")}

      post ->
        {:ok,
         socket
         |> assign(:page_title, post.title)
         |> assign(:post, post)
         |> assign(:comments, Comments.list_comments(post_id))
         |> assign(:comment_form, build_comment_form())
         |> assign(:reply_to, nil)
         |> assign(:report_modal, nil)}
    end
  end

  @impl true

  def handle_event("vote", %{"id" => post_id, "value" => value}, socket) do
    case socket.assigns.current_user do
      nil ->
        {:noreply, socket |> put_flash(:error, "投票するにはログインが必要です") |> redirect(to: "/login")}

      user ->
        case Posts.vote_post(user.id, post_id, String.to_integer(value)) do
          {:ok, updated_post} ->
            {:noreply, assign(socket, :post, updated_post)}

          {:error, :cannot_vote_own_post} ->
            {:noreply, put_flash(socket, :error, "自分の投稿には投票できません")}
        end
    end
  end

  def handle_event("vote_comment", %{"id" => comment_id, "value" => value}, socket) do
    case socket.assigns.current_user do
      nil ->
        {:noreply, socket |> put_flash(:error, "投票するにはログインが必要です") |> redirect(to: "/login")}

      user ->
        case Comments.vote_comment(user.id, comment_id, String.to_integer(value)) do
          {:ok, _} ->
            comments = Comments.list_comments(socket.assigns.post.id)
            {:noreply, assign(socket, :comments, comments)}

          {:error, :cannot_vote_own_comment} ->
            {:noreply, put_flash(socket, :error, "自分のコメントには投票できません")}
        end
    end
  end

  def handle_event("reply_to", %{"id" => comment_id}, socket) do
    comment = Comments.get_comment!(comment_id)
    form    = build_comment_form(%{parent_id: comment_id})

    {:noreply,
     socket
     |> assign(:reply_to, comment)
     |> assign(:comment_form, form)}
  end

  def handle_event("cancel_reply", _params, socket) do
    {:noreply,
     socket
     |> assign(:reply_to, nil)
     |> assign(:comment_form, build_comment_form())}
  end

  def handle_event("create_comment", %{"comment" => params}, socket) do
    case socket.assigns.current_user do
      nil -> {:noreply, redirect(socket, to: "/login")}

      user ->
        attrs =
          params
          |> Map.put("author_id", user.id)
          |> Map.put("post_id", socket.assigns.post.id)

        case Comments.create_comment(attrs) do
          {:ok, _} ->
            {:noreply,
             socket
             |> assign(:comments, Comments.list_comments(socket.assigns.post.id))
             |> assign(:reply_to, nil)
             |> assign(:comment_form, build_comment_form())}

          {:error, changeset} ->
            {:noreply, assign(socket, :comment_form, to_form(changeset, as: "comment"))}
        end
    end
  end

  def handle_event("delete_comment", %{"id" => comment_id}, socket) do
    user = socket.assigns.current_user
    Comments.delete_comment(comment_id, user.id, socket.assigns.post.subreddit_id)
    comments = Comments.list_comments(socket.assigns.post.id)
    {:noreply, assign(socket, :comments, comments)}
  end

  def handle_event("delete_post", _params, socket) do
    post = socket.assigns.post
    user = socket.assigns.current_user

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

  def handle_event("open_report_modal", %{"type" => type, "id" => id}, socket) do
    case socket.assigns.current_user do
      nil -> {:noreply, socket |> put_flash(:error, "ログインが必要です") |> redirect(to: "/login")}
      _   -> {:noreply, assign(socket, :report_modal, %{target_type: type, target_id: id})}
    end
  end

  def handle_event("close_report_modal", _params, socket) do
    {:noreply, assign(socket, :report_modal, nil)}
  end

  def handle_event("submit_report", params, socket) do
    attrs = %{
      "reporter_id" => socket.assigns.current_user.id,
      "target_type" => params["target_type"],
      "target_id"   => params["target_id"],
      "reason"      => params["reason"]
    }

    case Reports.create_report(attrs) do
      {:ok, _} ->
        {:noreply, socket |> assign(:report_modal, nil) |> put_flash(:info, "報告しました。")}
      {:error, :cannot_report_own_content} ->
        {:noreply, socket |> assign(:report_modal, nil) |> put_flash(:error, "自分のコンテンツは報告できません")}
      {:error, _} ->
        {:noreply, socket |> assign(:report_modal, nil) |> put_flash(:error, "報告に失敗しました")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto px-4 py-4">

      <%!-- 投稿本体 --%>
      <div class="bg-white border border-gray-200 rounded p-4 mb-4">
        <div class="flex gap-3">
          <div class="flex flex-col items-center gap-1">
            <button phx-click="vote" phx-value-id={@post.id} phx-value-value="1"
              class="text-gray-400 hover:text-orange-500">▲</button>
            <span class="text-sm font-bold"><%= @post.score %></span>
            <button phx-click="vote" phx-value-id={@post.id} phx-value-value="-1"
              class="text-gray-400 hover:text-blue-500">▼</button>
          </div>

          <div class="flex-1">
            <h1 class="text-xl font-bold text-gray-900 mb-1"><%= @post.title %></h1>

            <div class="text-xs text-gray-500 mb-3 flex gap-2">
              <.link navigate={~p"/r/#{@post.subreddit.name}"} class="hover:underline font-medium">
                r/<%= @post.subreddit.name %>
              </.link>
              <span>•</span>
              <.link navigate={~p"/u/#{@post.author.username}"} class="hover:underline">
                u/<%= @post.author.username %>
              </.link>
            </div>

            <%= if @post.type == "text" && @post.body do %>
              <p class="text-sm text-gray-800 whitespace-pre-wrap mb-3"><%= @post.body %></p>
            <% end %>

            <%= if @post.type == "link" do %>
              <a href={@post.url} target="_blank" rel="noopener noreferrer"
                class="text-sm text-blue-500 hover:underline break-all">
                <%= @post.url %> ↗
              </a>
            <% end %>

            <%= if @current_user && @current_user.id == @post.author_id do %>
              <button phx-click="delete_post" data-confirm="この投稿を削除しますか？"
                class="text-xs text-red-400 hover:text-red-600 mt-2">削除</button>
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
              <button phx-click="cancel_reply" class="hover:text-gray-700">キャンセル</button>
            </div>
          <% else %>
            <p class="text-sm font-medium mb-2">コメントを追加</p>
          <% end %>

          <.form for={@comment_form} phx-submit="create_comment">
            <input type="hidden" name="comment[parent_id]" value={@reply_to && @reply_to.id} />
            <textarea name="comment[body]" rows="4"
              placeholder="コメントを入力してください"
              class="w-full border border-gray-300 rounded p-2 text-sm resize-none focus:outline-none focus:border-blue-400">
            </textarea>
            <div class="flex justify-end mt-2">
              <.button type="submit" class="text-sm px-4 py-1">投稿する</.button>
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
          <.comment_tree comments={@comments} current_user={@current_user} />
        <% end %>
      </div>

    </div>

    <.report_modal report_modal={@report_modal} />
    """
  end

  defp build_comment_form(attrs \\ %{}) do
    %Comment{}
    |> Comment.changeset(attrs)
    |> to_form(as: "comment")
  end
end
```

**解説**

返信機能の状態管理に注目してください。

```elixir
assign(:reply_to, nil)      # nil のとき → トップレベルのコメント
assign(:reply_to, comment)  # セットされているとき → 返信フォームを表示
```

`reply_to` が `nil` のときは通常のコメントフォームを表示します。返信ボタンが押されると `reply_to` にコメントをセットし、フォームが「〇〇への返信」に変わります。

`parent_id` は hidden フィールドでフォームに含めます。

```heex
<input type="hidden" name="comment[parent_id]" value={@reply_to && @reply_to.id} />
```

`@reply_to && @reply_to.id` は `reply_to` が `nil` のとき `nil` を返し、セットされているときは ID を返します。

---

後編では HomeFeedLive・ProfileLive・SearchLive を実装します。
