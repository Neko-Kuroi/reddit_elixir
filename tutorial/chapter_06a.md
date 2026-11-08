# 第6章　画面実装（LiveView）前編

---

### この章で学ぶこと

- 作るもの: 画面（LiveView）7つ。前編では SubredditLive（コミュニティページ）と NewSubredditLive（コミュニティ作成）、中編では NewPostLive（投稿作成）と PostLive（投稿詳細）、後編では HomeFeedLive（ホーム Feed）・ProfileLive（プロフィール）・SearchLive（検索）を扱います
- 学ぶ考え方: LiveView のライフサイクル（mount → render → handle_event → 再描画）、状態の置き場所としての assigns、フォームの扱い（`to_form` と `phx-change` / `phx-submit`）、イベントと `phx-value-*`、画面ごとに違う `on_mount` の使い分け

### 前提

- 第5章が済んでいること（UserAuth の `on_mount` の3種と、Router による画面の保護の仕組み）
- 第4章の Context（Communities / Posts / Comments / Reports）が一通り書けていること。この章の画面は、それらを呼び出す側になります

### 全体の中での位置

この章は Web 層の中心です。第4章の Context が「データのルール」を担当するのに対して、LiveView は「受け取って、表示して、操作を Context に渡す」役割です。LiveView の中にはデータのルールを書かず、判断は Context に任せる、という分担を意識しながら読んでください。

> この章のコードについて: 各 LiveView は、実ファイルの全文をそのまま掲載しています（節の区切りコメントも含みます）。完成形は全コード付録3（appendix_code_03_web.md）にも収録しています。

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

（この `MyLive` は仕組みを説明するための最小の例で、このアプリのコードではありません。）

`assigns` は LiveView の状態です。`assign/3` で更新すると自動的に `render/1` が再実行されます。

**読み解き**

3つの関数の役割を、動きを言葉でなぞって押さえます。

- `mount/3` は「画面の準備」です。URL のパラメーター（`params`）とセッションを受け取り、最初に必要なデータを Context から取ってきて assigns に入れます。戻り値は `{:ok, socket}` です。
- `render/1` は「assigns から HTML を作る」関数です。自分で呼ぶことはなく、assigns が変わるたびに LiveView の側が呼び直します。
- `handle_event/3` は「操作の受け付け」です。ボタンの `phx-click` やフォームの送信が、イベント名とパラメーターとして届きます。ここで assigns を更新すると、続けて `render/1` が再実行され、**変わった部分の差分だけ**がブラウザに送られます。ページ全体を送り直さないことが、LiveView の軽さの理由です。

知っておくとよい性質が1つあります。`mount/3` は、1回の表示につき**2回呼ばれます**。最初は通常の HTTP リクエストへの応答として（静的な HTML を返すため）、続いて WebSocket がつながったときにもう1回です。そのため、mount の中に「1回だけ起きてほしい処理」（メール送信のような副作用）を書くと、2回起きてしまいます。mount はデータの読み取りだけにしておくのが安全です。

もう1つ、この章で何度も出てくるのが、画面の冒頭に書く `on_mount` の宣言です（第5章で作った仕組み）。この章の画面では、次の2種類を使い分けます。

- `on_mount {RedditCloneWeb.UserAuth, :fetch_current_user}` — 誰でも見られる画面。ログインしていれば `current_user` が assigns に入り、未ログインなら `nil` になります
- `on_mount {RedditCloneWeb.UserAuth, :require_auth}` — ログインが必須の画面。未ログインなら、mount が始まる前にログイン画面へ飛ばされます

どちらの画面でも `socket.assigns.current_user` でログイン中のユーザーを参照できます。「未ログインがあり得るかどうか」で、後のハンドラの書き方が変わってきます。

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
```

**読み解き**

まず mount です。URL の `name` からコミュニティを探し、無ければ `put_flash` でメッセージを入れてトップへ `redirect` します。

- **フラッシュメッセージ**は「次の画面に1回だけ表示する通知」です。`put_flash(socket, :error, "...")` で入れた内容は、遷移先の画面に表示されて消えます（表示そのものはレイアウト側の役割で、第8章で触れます）。
- mount の中で `redirect` すると、その画面の表示自体を取りやめて、別のページへ移動します。戻り値は通常の mount と同じ `{:ok, socket}` の形で、socket の側に移動の指示が乗っています。

`joined?` は、第4章で学んだ「関数の複数節とパターンマッチ」の応用です。未ログイン（`nil`）の節が先にあり、`false` を即答します。ログイン済みの場合は、Context の `Communities.member?/2` に聞きます。「場合分けを if ではなく節の並びで書く」という書き方が、画面側でも使われています。

`join`（参加）の受け手は、登録の結果を必ず見るようにしています。成功（`{:ok, _}`）したら画面を「参加中」にします。失敗（`{:error, _}`）した場合は思い込みで表示を変えず、`joined?` で実際の参加状態を調べ直して画面に合わせます。参加には「1人1回だけ」という制約があるため、別のタブで参加済みだった場合などに失敗が起こり得ます。結果を見ずに「参加中」と表示してしまうと、画面とデータベースが食い違ってしまうので、ここは大事な書き方です。すぐ下の `leave`（脱退）の受け手も、同じ考え方で結果を場合分けしています。

サイドバーの「投稿する」リンクは `<.link navigate={...}>` です。`navigate` は LiveView 同士の移動で、ページ全体を読み直さずに画面を切り替えます（移動先では、その LiveView の mount から処理が始まります）。これに対して、mount やハンドラで使う `redirect` は通常の HTTP リダイレクトで、いったん LiveView を離れます。使い分けは、「同じ画面の中の状態変更は assigns の更新」「別の LiveView への移動は `navigate`」「LiveView の外へ出る・入り直す場合は `redirect`」です。

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

最後に、報告まわりの配線を確認しておきます。この画面には、報告のための部品が3点セットで入っています。

1. mount での初期化: `assign(:report_modal, nil)`（閉じている状態）
2. render の末尾: `<.report_modal report_modal={@report_modal} />`（モーダル本体の描画。第7章で作る部品です）
3. ファイル末尾の3つのハンドラ: `open_report_modal`（開く）、`close_report_modal`（閉じる）、`submit_report`（送信する）

モーダル本体は部品（第7章）ですが、「開いているかどうか」という状態と、クリックの受け手は画面側が持ちます。この分担は第7章で改めて説明します。SubredditLive と、次の中編で作る PostLive、そして後編の3画面は、すべて同じ3点セットを持っています。

---

## 6-3　NewSubredditLive

NewSubredditLive はコミュニティの新規作成ページです。作成者は自動的にそのコミュニティのモデレーターになります（第4章の `create_subreddit/1`）。

```elixir
# lib/reddit_clone_web/live/new_subreddit_live.ex
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
```

**読み解き**

フォームの流れを、順番に追います。

1. mount で空のチェンジセットを作り、`assign_form` で `to_form/2` に通して `@form` に入れます。`to_form` は「チェンジセットを、画面のフォームとして使える形に変換する」関数です。
2. 入力のたびに `phx-change="validate"` で `validate` ハンドラが呼ばれ、チェンジセットを作り直して `@form` を差し替えます。このとき `Map.put(:action, :validate)` と action を付けるのが決まりで、action の無いチェンジセットでは、フォームはエラーを表示しません（まだ送信していない入力を、いきなり責めないための仕組みです）。
3. 送信すると `phx-submit="create"` で `create` ハンドラが呼ばれ、Context に保存を頼みます。

render のコミュニティ名の欄には、入力中の名前が `r/○○` の形でその場に表示される仕掛けがあります（`@form[:name].value` を読んでいます）。入力のたびに validate が走って `@form` が差し替わるので、表示がそのまま追いつきます。「状態が変われば画面が追いつく」という LiveView の基本が、ここにも表れています。

`handle_event("create", ...)` で `owner_id` をサーバー側でセットします。

```elixir
attrs = Map.put(params, "owner_id", socket.assigns.current_user.id)
```

`owner_id` をフォームの hidden フィールドに入れる方法もありますが、クライアント側で改ざんできてしまいます。サーバー側でセットすることで安全に処理できます。

---

中編では NewPostLive と PostLive を実装します。
