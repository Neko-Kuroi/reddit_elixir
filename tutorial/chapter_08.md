# 第8章　仕上げ

---

### この章で学ぶこと

- 作るもの: 全画面共通のナビゲーションバー（`root.html.heex`）と、アプリ全体の動作確認の手順
- 学ぶ考え方: レイアウトの仕組み（root レイアウトと `@inner_content`）、検証済みルート `~p` の届く範囲、フラッシュメッセージが表示される場所、本全体の振り返り

### 前提

- 第7章までが済み、画面と部品がすべてそろっていること

### 全体の中での位置

Web 層の仕上げです。これまでの章で作った画面は、すべて「中身」でした。この章では、全画面の外側を包むレイアウトにナビゲーションバーを置き、アプリとして一通り動くことを確かめます。

---

## 8-1　ナビゲーションバー

ナビゲーションバーは全画面の上部に表示する共通の UI です。`root.html.heex` に記述することで全ての LiveView に自動的に適用されます。

```heex
<%!-- lib/reddit_clone_web/components/layouts/root.html.heex --%>
<!DOCTYPE html>
<html lang="ja">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="csrf-token" content={get_csrf_token()} />
    <.live_title suffix=" · reddit_clone">
      <%= assigns[:page_title] || "reddit_clone" %>
    </.live_title>
    <link phx-track-static rel="stylesheet" href={~p"/assets/app.css"} />
    <script defer phx-track-static type="text/javascript" src={~p"/assets/app.js"}>
    </script>
  </head>

  <body class="bg-gray-100 min-h-screen">

    <%!-- ナビゲーションバー --%>
    <nav class="bg-white border-b border-gray-200 sticky top-0 z-30">
      <div class="max-w-5xl mx-auto px-4 h-12 flex items-center gap-4">

        <%!-- ロゴ --%>
        <a href="/" class="flex items-center gap-1 shrink-0">
          <span class="text-orange-500 text-xl font-black">🔴</span>
          <span class="font-bold text-gray-800 hidden sm:block">reddit_clone</span>
        </a>

        <%!-- 検索フォーム --%>
        <form action="/search" method="get" class="flex-1 max-w-xl">
          <div class="relative">
            <input
              type="text"
              name="q"
              value={assigns[:query] || ""}
              placeholder="検索..."
              class="w-full border border-gray-300 rounded-full px-4 py-1.5 text-sm bg-gray-50 focus:outline-none focus:border-blue-400 focus:bg-white"
            />
            <button
              type="submit"
              class="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
            >
              🔍
            </button>
          </div>
        </form>

        <%!-- 右側: 認証ボタン --%>
        <div class="flex items-center gap-2 shrink-0">
          <%= if @current_user do %>
            <%!-- ログイン済み --%>
            <a
              href={"/u/#{@current_user.username}"}
              class="text-sm text-gray-700 hover:text-blue-500 font-medium hidden sm:block"
            >
              u/<%= @current_user.username %>
            </a>
            <a
              href="/subreddits/new"
              class="text-sm text-gray-500 hover:text-gray-700 px-2 py-1 hidden sm:block"
            >
              ＋ 作成
            </a>
            <a
              href="/logout"
              data-method="delete"
              class="text-sm border border-gray-300 rounded-full px-3 py-1 hover:bg-gray-50"
            >
              ログアウト
            </a>
          <% else %>
            <%!-- 未ログイン --%>
            <a
              href="/login"
              class="text-sm border border-blue-500 text-blue-500 rounded-full px-3 py-1 hover:bg-blue-50"
            >
              ログイン
            </a>
            <a
              href="/register"
              class="text-sm bg-blue-500 text-white rounded-full px-3 py-1 hover:bg-blue-600"
            >
              登録
            </a>
          <% end %>
        </div>

      </div>
    </nav>

    <%!-- メインコンテンツ --%>
    <main>
      <%= @inner_content %>
    </main>

  </body>
</html>
```

**読み解き**

`root.html.heex` は、HTML の骨格（`<head>` と `<body>` の外側）を作るレイアウトです。各 LiveView の `render/1` が作った HTML は、`<%= @inner_content %>` の位置に入ります。つまり、画面ごとの中身は LiveView が、外側の枠はこのファイルが担当します。

タイトルは `<.live_title>` が作り、各画面が mount で入れた `page_title`（`assigns[:page_title]`）を使います。画面ごとにタイトルが変わるのは、この受け渡しがあるためです。

`root.html.heex` で `@current_user` を使っています。これは Router の `pipeline :browser` に追加した `plug :fetch_current_user` が全リクエストで自動的にセットするものです。

```elixir
# router.ex
pipeline :browser do
  ...
  plug :fetch_current_user   # ← これが @current_user をセットする
end
```

`<link href={~p"/assets/app.css"} />` のような静的ファイルの指定にも `~p` が使われています。`~p` は**検証済みルート**で、書かれたパスが Router に実在するかを、コンパイル時に照合します（第5章の Router で、画面の URL に使ったのと同じ仕組みです）。第7章の PostCard で、URL を文字列で直接組み立てた `post_url/1` と対比しておくと、「検証が効く場所では `~p`、効かない場所では文字列」という使い分けが見えてきます。

各章で `put_flash` してきたフラッシュメッセージの表示は、このファイルではなく、`phx.new` で生成されるアプリ側のレイアウト（`app.html.heex`、雛形のまま使うもの）が担います。本書のコード一式（全コード付録）には、そのファイルは含まれていません。「メッセージを入れるのは各画面、出すのはレイアウト」という分担だけ、ここで押さえておきます。

`sticky top-0 z-30` で画面をスクロールしてもナビバーが上部に固定されます。`z-30` はモーダル（`z-40`・`z-50`）より低い値にして、モーダルがナビバーの上に表示されるようにしています。

`assigns[:query] || ""` の `[]` アクセスは安全な参照です。`@query` と書くと SearchLive 以外のページでエラーになります。`assigns[:query]` は存在しないキーのとき `nil` を返すため安全です。

ナビバーの検索フォームは、通常の HTML フォーム（GET）です。送信すると `/search?q=キーワード` という URL が作られ、第6章の SearchLive がそれを受けます。「検索の入り口はレイアウト、受け手は SearchLive、検索の中身は Context」というつながりです。

ログアウトリンクの `data-method="delete"` は Phoenix が生成する JavaScript によって DELETE リクエストに変換されます。通常の `<a>` タグは GET リクエストしか送れないためです。

---

## 8-2　動作確認の手順

サーバーを起動します。

```bash
mix phx.server
```

以下の順番で動作を確認してください。

### ① ユーザー登録

`http://localhost:4000/register` にアクセスして新しいアカウントを作ります。

- [ ] username・email・password を入力できる
- [ ] 入力中にリアルタイムでバリデーションが動く
- [ ] 登録後に自動ログインしてホームに飛ぶ

### ② コミュニティを作成する

`http://localhost:4000/subreddits/new` にアクセスします。

- [ ] `elixir` という名前でコミュニティを作成できる
- [ ] 作成後に `r/elixir` ページに飛ぶ
- [ ] サイドバーに「参加中」と表示される

### ③ 投稿を作成する

`r/elixir` ページの「投稿する」ボタンをクリックします。

- [ ] テキスト投稿とリンク投稿のタブが切り替わる
- [ ] テキスト投稿を作成できる
- [ ] 投稿後に詳細ページに飛ぶ

### ④ コメントを投稿する

投稿詳細ページでコメントを投稿します。

- [ ] コメントが一覧に表示される
- [ ] 「返信」ボタンを押すとフォームが変わる
- [ ] 返信がネストして表示される

### ⑤ 投票する

投稿とコメントに投票します。

- [ ] ▲ でスコアが増える
- [ ] もう一度 ▲ を押すとキャンセルされる（スコアが戻る）
- [ ] ▼ を押すとスコアが減る
- [ ] 自分の投稿に投票しようとするとエラーになる

### ⑥ 別のユーザーで試す

別のブラウザまたはシークレットウインドウで別のアカウントを作り、以下を確認します。

- [ ] `r/elixir` に Join できる
- [ ] ホーム Feed に `r/elixir` の投稿が表示される
- [ ] 最初のユーザーの投稿に投票できる
- [ ] プロフィールページで Karma が増えている

### ⑦ 検索する

ナビバーの検索フォームにキーワードを入力して検索します。

- [ ] 投稿とコミュニティが両方ヒットする
- [ ] 大文字小文字を無視して検索できる

### ⑧ 報告と削除を試す

第6章・第7章で配線した、モデレーションの最小限の機能を確認します。

- [ ] 別のユーザーの投稿で「報告」を押すとモーダルが開き、理由を選んで報告できる（ホーム Feed や検索結果など、他の画面でも同じように開く）
- [ ] 自分の投稿には「報告」が出ず、「削除」が出る
- [ ] 自分の投稿を削除すると、コミュニティページに戻る
- [ ] コミュニティのモデレーターは、他人の投稿やコメントも削除できる

---

## 8-3　よくあるエラーと対処法

| 症状 | 原因 | 直し方 |
|------|------|--------|
| `(DBConnection.ConnectionError) connection not available` と出て DB につながらない | PostgreSQL が起動していない | PostgreSQL を起動する（macOS なら `brew services start postgresql`、Linux なら `sudo service postgresql start`） |
| `(Ecto.MigrationError) ...` と出る | マイグレーションが完了していない | `mix ecto.migrate` を実行する |
| `could not compile dependency :bcrypt_elixir` と出て依存関係のコンパイルで止まる | C コンパイラが無い（bcrypt は C の処理を含む） | macOS なら `xcode-select --install`、Ubuntu なら `sudo apt-get install build-essential` でコンパイラを入れる |
| `(KeyError) key :current_user not found` と出る | `fetch_current_user` Plug が適用されていない | `router.ex` の `pipeline :browser` に `plug :fetch_current_user` が含まれているか確認する |

---

## 確認問題

この章の問題は、本全体の振り返りです。

1. 投票ボタンを押してから、スコアが画面に反映されるまでの流れを、画面（LiveView）・Context・Data（スキーマと DB）の3層で説明してください。
2. 「データのルールは Context に集める」という設計は、投稿の削除の処理のどこに表れていますか。
3. ログイン状態が、各画面の `@current_user` に届くまでの経路を、Cookie から順に説明してください。
4. 部品（PostCard など）と画面（LiveView）の役割分担を、「状態」と「イベントの受け手」の2点で説明してください。
5. この本に新しい画面を1つ足すとしたら、何をどの順番で作りますか。本文でたどった順番に沿って答えてください。

---

## まとめと次章へのつながり

この章では以下を完了しました。

```
✅ ナビゲーションバーを実装した
✅ アプリの動作確認を行った
```

ここが本の最後の章です。次章はありません。代わりに、本全体を振り返ります。

### 全章の振り返り

このチュートリアルを通じて以下を学びました。

| 章 | 学んだこと |
|----|-----------|
| 第1章 | Phoenix プロジェクトの構造と初期設定 |
| 第2章 | テーブル設計・マイグレーション・インデックスの考え方 |
| 第3章 | Ecto スキーマ・チェンジセット・バリデーション |
| 第4章 | Context パターン・投票ロジック・トランザクション |
| 第5章 | セッション管理・Phoenix.Token・セキュリティ対策 |
| 第6章 | LiveView のライフサイクル・リアルタイム更新 |
| 第7章 | コンポーネント・再帰コンポーネント |
| 第8章 | 全体の組み合わせと動作確認 |

### 学びの地図（考え方と登場する章）

| 考え方 | 主な登場章 |
|--------|-----------|
| パイプ演算子とチェンジセット | 第3章 |
| 関数の複数節とパターンマッチ | 第4章（投票処理）、第6章（mount と `joined?`） |
| トランザクション | 第4章 |
| Plug とパイプライン | 第5章 |
| Phoenix.Token と on_mount | 第5章 |
| LiveView のライフサイクル（mount / render / handle_event） | 第6章 |
| 再帰 | 第4章（ツリーの組み立て）、第7章（CommentTree） |
| 状態を持たない部品と、画面との分担 | 第7章 |
| レイアウトと検証済みルート | 第8章 |

### 次のステップ

このアプリをベースに以下の機能を追加してみましょう。

- **フレア（Flair）** — 投稿にタグをつける
- **ユーザーアバター** — プロフィール画像
- **通知** — コメント返信の通知
- **モデレーションキュー** — 報告された投稿の一覧
- **テスト** — Context と LiveView のテストを書く

Elixir と Phoenix の世界へようこそ。

---

## 確認問題の答え

1. 画面のボタンが `phx-click="vote"` のイベントを LiveView に送り、`handle_event("vote", ...)` が Context の `Posts.vote_post/3`（または `Comments.vote_comment/3`）を呼びます。Context は Data 層の Vote スキーマと DB を使って投票を記録し、投稿の score・hot_score と投稿者の Karma を更新して、`{:ok, 更新後の投稿}` を返します。LiveView はそれを受けて assigns を差し替え、render の差分がブラウザに送られます。
2. 削除できるかどうかの判定（本人の投稿か、コミュニティのモデレーターか）は、画面ではなく Context の `delete_post/3` / `delete_comment/3` の中あります。画面（PostLive）は、返ってきた `{:ok, _}` / `{:error, :unauthorized}` によって表示を切り替えるだけです。判定の中で、モデレーターかどうかは `Communities.moderator?/2` に聞く形で、ルールの置き場所も Context 同士でそろえています。
3. ログイン時に、コントローラー（SessionController）がセッションへ `user_id` を保存し、ブラウザには署名された Cookie が渡ります。以後のリクエストでは Cookie が自動で送られ、Router の `plug :fetch_current_user` がセッションからユーザーを取得して conn に入れます。LiveView では、各画面の `on_mount`（UserAuth）がセッションから同じ取得を行い、`socket.assigns.current_user` に入れます。
4. 状態は画面が持ちます（例: 報告モーダルの開閉は、画面の assigns が決めます）。部品は、受け取った値から HTML を作るだけで状態を持ちません。イベントの受け手も画面です。部品のボタンが送る `phx-click` は、表示中の LiveView の `handle_event/3` が処理します。
5. この本の順番では、マイグレーション（第2章）→ スキーマ（第3章）→ Context（第4章）→ Router の保護と認証の確認（第5章）→ LiveView（第6章）→ 必要なら部品の切り出し（第7章）→ レイアウトへの組み込み（第8章）です。データの置き場所から決めて、ルールを Context に集め、画面は最後に薄く作る、という流れが本全体の進め方でした。
