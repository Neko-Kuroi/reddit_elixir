# 第6章　画面実装（LiveView）前編

---

## 6-1　LiveView とは

Phoenix LiveView はサーバーサイドでレンダリングしながら、リアルタイムの UI を実現する仕組みです。

従来の Web アプリは「ページを操作するたびに HTTP リクエストを送って画面を再読み込みする」か「JavaScript で動的に更新する」かのどちらかでした。LiveView はその中間の選択肢です。

```
従来の HTTP
  ボタンを押す → HTTP リクエスト → ページ全体を再読み込み

JavaScript SPA
  ボタンを押す → API を呼ぶ → DOM を書き換える
  → JavaScript を大量に書く必要がある

LiveView
  ボタンを押す → WebSocket でサーバーに通知
             → サーバーが差分を計算
             → 変わった部分だけをブラウザに送る
  → JavaScript をほぼ書かずにリアルタイム更新できる
```

---

### LiveView のライフサイクル

LiveView は以下の流れで動作します。

```
① mount/3
   ページが最初に表示されるとき呼ばれる
   → assigns（状態）を初期化する

② render/1
   assigns が変わるたびに呼ばれる
   → HTML を生成する

③ handle_event/3
   ユーザーが操作したとき呼ばれる（ボタン・フォームなど）
   → assigns を更新する → render が再実行される
```

```elixir
defmodule MyLive do
  use RedditCloneWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :count, 0)}   # ① 初期化
  end

  def render(assigns) do               # ② 描画
    ~H"""
    <p><%= @count %></p>
    <button phx-click="increment">+1</button>
    """
  end

  def handle_event("increment", _params, socket) do  # ③ 操作
    {:noreply, update(socket, :count, &(&1 + 1))}
  end
end
```

`assigns` は LiveView の状態です。`assign/3` で更新すると自動的に `render/1` が再実行されます。

---

## 6-2　SubredditLive

SubredditLive はコミュニティのメインページです。投稿一覧の表示・ソート切り替え・Join/Leave・投票・報告を担当します。

```elixir
# lib/reddit_clone_web/live/subreddit_live.ex
defmodule RedditCloneWeb.SubredditLive do
  use RedditCloneWeb, :live_view

  import RedditCloneWeb.Components.PostCard
  import RedditCloneWeb.Components.ReportModal

  alias RedditClone.Communities
  alias RedditClone.Posts
  alias RedditClone.Reports

  on_mount {RedditCloneWeb.UserAuth, :fetch_current_user}

  @impl true
  def mount(%{"name" => name}, _session, socket) do
    case Communities.get_subreddit_by_name(name) do
      nil ->
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

  @impl true
  def handle_event("sort", %{"value" => sort}, socket) do
    posts = Posts.list_posts(socket.assigns.subreddit.id, sort, 1)

    {:noreply,
     socket
     |> assign(:sort, sort)
     |> assign(:page, 1)
     |> assign(:has_more?, length(posts) == 25)
     |> assign(:posts, posts)}
  end

  def handle_event("load_more", _params, socket) do
    next_page = socket.assigns.page + 1
    new_posts = Posts.list_posts(socket.assigns.subreddit.id, socket.assigns.sort, next_page)

    {:noreply,
     socket
     |> assign(:page, next_page)
     |> assign(:has_more?, length(new_posts) == 25)
     |> assign(:posts, socket.assigns.posts ++ new_posts)}
  end

  def handle_event("join", _params, socket) do
    case socket.assigns.current_user do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "参加するにはログインが必要です")
         |> redirect(to: "/login")}

      user ->
        Communities.join_subreddit(user.id, socket.assigns.subreddit.id)
        {:noreply, assign(socket, :joined?, true)}
    end
  end

  def handle_event("leave", _params, socket) do
    case Communities.leave_subreddit(
           socket.assigns.current_user.id,
           socket.assigns.subreddit.id
         ) do
      {:ok, _}                    -> {:noreply, assign(socket, :joined?, false)}
      {:error, :owner_cannot_leave} ->
        {:noreply, put_flash(socket, :error, "作成者はコミュニティを脱退できません")}
    end
  end

  def handle_event("vote", %{"id" => post_id, "value" => value}, socket) do
    case socket.assigns.current_user do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "投票するにはログインが必要です")
         |> redirect(to: "/login")}

      user ->
        case Posts.vote_post(user.id, post_id, String.to_integer(value)) do
          {:ok, updated_post} ->
            posts = Enum.map(socket.assigns.posts, fn post ->
              if post.id == updated_post.id, do: updated_post, else: post
            end)
            {:noreply, assign(socket, :posts, posts)}

          {:error, :cannot_vote_own_post} ->
            {:noreply, put_flash(socket, :error, "自分の投稿には投票できません")}
        end
    end
  end

  def handle_event("open_report_modal", %{"type" => type, "id" => id}, socket) do
    case socket.assigns.current_user do
      nil ->
        {:noreply, socket |> put_flash(:error, "報告するにはログインが必要です") |> redirect(to: "/login")}
      _ ->
        {:noreply, assign(socket, :report_modal, %{target_type: type, target_id: id})}
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
      {:ok, _}    ->
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
    <div class="max-w-4xl mx-auto px-4 py-4 flex gap-4">
      <div class="flex-1">

        <div class="bg-white border border-gray-200 rounded p-2 mb-4 flex gap-2">
          <button phx-click="sort" phx-value-value="hot" class={tab_class(@sort, "hot")}>
            🔥 Hot
          </button>
          <button phx-click="sort" phx-value-value="new" class={tab_class(@sort, "new")}>
            ✨ New
          </button>
        </div>

        <%= if @posts == [] do %>
          <p class="text-gray-500 text-center py-8">まだ投稿がありません</p>
        <% else %>
          <%= for post <- @posts do %>
            <.post_card post={post} show_subreddit={false} current_user={@current_user} />
          <% end %>

          <%= if @has_more? do %>
            <div class="text-center py-4">
              <button phx-click="load_more"
                class="px-6 py-2 border border-gray-300 rounded text-sm text-gray-600 hover:bg-gray-50">
                もっと見る
              </button>
            </div>
          <% end %>
        <% end %>

      </div>

      <div class="w-72 shrink-0">
        <div class="bg-white border border-gray-200 rounded p-4">
          <h2 class="font-bold text-lg mb-2">r/<%= @subreddit.name %></h2>

          <%= if @subreddit.description do %>
            <p class="text-sm text-gray-600 mb-4"><%= @subreddit.description %></p>
          <% end %>

          <%= if @current_user do %>
            <%= if @joined? do %>
              <button phx-click="leave"
                class="w-full border border-blue-500 text-blue-500 rounded-full py-1 text-sm hover:bg-blue-50">
                参加中
              </button>
            <% else %>
              <button phx-click="join"
                class="w-full bg-blue-500 text-white rounded-full py-1 text-sm hover:bg-blue-600">
                参加する
              </button>
            <% end %>

            <.link navigate={~p"/r/#{@subreddit.name}/submit"}
              class="block w-full mt-2 border border-gray-300 text-center rounded-full py-1 text-sm hover:bg-gray-50">
              投稿する
            </.link>
          <% end %>
        </div>
      </div>
    </div>

    <.report_modal report_modal={@report_modal} />
    """
  end

  defp joined?(nil, _), do: false
  defp joined?(user, subreddit_id), do: Communities.member?(user.id, subreddit_id)

  defp tab_class(current, tab) when current == tab,
    do: "px-4 py-1 rounded bg-gray-200 font-bold text-sm"
  defp tab_class(_, _),
    do: "px-4 py-1 rounded hover:bg-gray-100 text-sm text-gray-600"
end
```

**解説**

`has_more?` でページネーションを管理します。

```elixir
assign(:has_more?, length(posts) == 25)
```

取得件数がページサイズ（25件）と一致するとき、まだ次のページがあると判断します。25件未満なら最後のページです。

`load_more` は取得した投稿を既存のリストに追記します。

```elixir
assign(:posts, socket.assigns.posts ++ new_posts)
```

ページ全体を入れ替えるのではなく追記するため、スクロール位置が保たれます。

投票後は変更があった投稿だけを更新します。

```elixir
Enum.map(socket.assigns.posts, fn post ->
  if post.id == updated_post.id, do: updated_post, else: post
end)
```

リスト全体を再取得しないため効率的です。

---

## 6-3　NewSubredditLive

```elixir
# lib/reddit_clone_web/live/new_subreddit_live.ex
defmodule RedditCloneWeb.NewSubredditLive do
  use RedditCloneWeb, :live_view

  alias RedditClone.Communities
  alias RedditClone.Communities.Subreddit

  on_mount {RedditCloneWeb.UserAuth, :require_auth}

  @impl true
  def mount(_params, _session, socket) do
    changeset = Subreddit.changeset(%Subreddit{}, %{})

    {:ok,
     socket
     |> assign(:page_title, "コミュニティを作成")
     |> assign_form(changeset)}
  end

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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-lg mx-auto mt-12 px-4">
      <h1 class="text-2xl font-bold mb-6">コミュニティを作成</h1>

      <.form for={@form} phx-change="validate" phx-submit="create"
        class="bg-white border border-gray-200 rounded p-6">

        <div class="mb-4">
          <.input field={@form[:name]} label="コミュニティ名" placeholder="例: elixir" />
          <p class="text-xs text-gray-400 mt-1">
            英数字とアンダースコアのみ・3〜21文字
          </p>
        </div>

        <div class="mb-6">
          <.input field={@form[:description]} type="textarea"
            label="説明（任意）" rows="3"
            placeholder="このコミュニティは何について話す場所ですか？" />
        </div>

        <.button type="submit" class="w-full">コミュニティを作成する</.button>
      </.form>
    </div>
    """
  end

  defp assign_form(socket, changeset) do
    assign(socket, :form, to_form(changeset, as: "subreddit"))
  end
end
```

**解説**

`handle_event("create", ...)` で `owner_id` をサーバー側でセットします。

```elixir
attrs = Map.put(params, "owner_id", socket.assigns.current_user.id)
```

`owner_id` をフォームの hidden フィールドに入れる方法もありますが、クライアント側で改ざんできてしまいます。サーバー側でセットすることで安全に処理できます。

---

後編では NewPostLive と PostLive を実装します。
