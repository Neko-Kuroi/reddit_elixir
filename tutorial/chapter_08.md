# 第8章　仕上げ

---

## 8-1　ナビゲーションバー

ナビゲーションバーは全画面の上部に表示する共通の UI です。`root.html.heex` に記述することで全ての LiveView に自動的に適用されます。

```heex
<%!-- lib/reddit_clone_web/components/layouts/root.html.heex -->
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
              class="w-full border border-gray-300 rounded-full px-4 py-1.5 text-sm bg-gray-50
                     focus:outline-none focus:border-blue-400 focus:bg-white"
            />
            <button type="submit"
              class="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600">
              🔍
            </button>
          </div>
        </form>

        <%!-- 右側: 認証ボタン --%>
        <div class="flex items-center gap-2 shrink-0">
          <%= if @current_user do %>
            <a href={"/u/#{@current_user.username}"}
              class="text-sm text-gray-700 hover:text-blue-500 font-medium hidden sm:block">
              u/<%= @current_user.username %>
            </a>
            <a href="/subreddits/new"
              class="text-sm text-gray-500 hover:text-gray-700 px-2 py-1 hidden sm:block">
              ＋ 作成
            </a>
            <a href="/logout" data-method="delete"
              class="text-sm border border-gray-300 rounded-full px-3 py-1 hover:bg-gray-50">
              ログアウト
            </a>
          <% else %>
            <a href="/login"
              class="text-sm border border-blue-500 text-blue-500 rounded-full px-3 py-1 hover:bg-blue-50">
              ログイン
            </a>
            <a href="/register"
              class="text-sm bg-blue-500 text-white rounded-full px-3 py-1 hover:bg-blue-600">
              登録
            </a>
          <% end %>
        </div>

      </div>
    </nav>

    <main>
      <%= @inner_content %>
    </main>

  </body>
</html>
```

**解説**

`root.html.heex` で `@current_user` を使っています。これは Router の `pipeline :browser` に追加した `plug :fetch_current_user` が全リクエストで自動的にセットするものです。

```elixir
# router.ex
pipeline :browser do
  ...
  plug :fetch_current_user   # ← これが @current_user をセットする
end
```

`sticky top-0 z-30` で画面をスクロールしてもナビバーが上部に固定されます。`z-30` はモーダル（`z-40`・`z-50`）より低い値にして、モーダルがナビバーの上に表示されるようにしています。

`assigns[:query] || ""` の `[]` アクセスは安全な参照です。`@query` と書くと SearchLive 以外のページでエラーになります。`assigns[:query]` は存在しないキーのとき `nil` を返すため安全です。

ログアウトリンクの `data-method="delete"` は Phoenix が生成する JavaScript によって DELETE リクエストに変換されます。通常の `<a>` タグは GET リクエストしか送れないためです。

---

## 8-2　動作確認の手順

サーバーを起動します。

```bash
mix phx.server
```

以下の順番で動作を確認してください。

---

### ① ユーザー登録

`http://localhost:4000/register` にアクセスして新しいアカウントを作ります。

確認するポイント
- username・email・password を入力
- 入力中にリアルタイムでバリデーションが動くか
- 登録後に自動ログインしてホームに飛ぶか

---

### ② コミュニティを作成する

`http://localhost:4000/subreddits/new` にアクセスします。

確認するポイント
- `elixir` という名前でコミュニティを作成する
- 作成後に `r/elixir` ページに飛ぶか
- サイドバーに「参加中」と表示されるか

---

### ③ 投稿を作成する

`r/elixir` ページの「投稿する」ボタンをクリックします。

確認するポイント
- テキスト投稿とリンク投稿のタブが切り替わるか
- テキスト投稿を作成してみる
- 投稿後に詳細ページに飛ぶか

---

### ④ コメントを投稿する

投稿詳細ページでコメントを投稿します。

確認するポイント
- コメントが一覧に表示されるか
- 「返信」ボタンを押すとフォームが変わるか
- 返信がネストして表示されるか

---

### ⑤ 投票する

投稿とコメントに投票します。

確認するポイント
- ▲ でスコアが増えるか
- もう一度 ▲ を押すとキャンセルされるか（スコアが戻るか）
- ▼ を押すとスコアが減るか
- 自分の投稿に投票しようとするとエラーになるか

---

### ⑥ 別のユーザーで試す

別のブラウザまたはシークレットウインドウで別のアカウントを作り、以下を確認します。

確認するポイント
- `r/elixir` に Join できるか
- ホーム Feed に `r/elixir` の投稿が表示されるか
- 最初のユーザーの投稿に投票できるか
- プロフィールページでKarmaが増えているか

---

### ⑦ 検索する

ナビバーの検索フォームにキーワードを入力して検索します。

確認するポイント
- 投稿とコミュニティが両方ヒットするか
- 大文字小文字を無視して検索できるか

---

## 8-3　よくあるエラーと対処法

**DBの接続エラー**

```
(DBConnection.ConnectionError) connection not available
```

PostgreSQL が起動していない可能性があります。

```bash
# macOS (Homebrew)
brew services start postgresql

# Linux
sudo service postgresql start
```

---

**マイグレーションのエラー**

```
(Ecto.MigrationError) ...
```

マイグレーションが完了していない可能性があります。

```bash
mix ecto.migrate
```

---

**bcrypt のコンパイルエラー**

```
could not compile dependency :bcrypt_elixir
```

C コンパイラが必要です。

```bash
# macOS
xcode-select --install

# Ubuntu
sudo apt-get install build-essential
```

---

**LiveView の assigns エラー**

```
(KeyError) key :current_user not found
```

`fetch_current_user` Plug が適用されていない可能性があります。`router.ex` の `pipeline :browser` に `plug :fetch_current_user` が含まれているか確認してください。

---

## まとめ

この章では以下を完了しました。

```
✅ ナビゲーションバーを実装した
✅ アプリの動作確認を行った
```

---

## 全章の振り返り

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

**次のステップ**

このアプリをベースに以下の機能を追加してみましょう。

- **フレア（Flair）** — 投稿にタグをつける
- **ユーザーアバター** — プロフィール画像
- **通知** — コメント返信の通知
- **モデレーションキュー** — 報告された投稿の一覧
- **テスト** — Context と LiveView のテストを書く

Elixir と Phoenix の世界へようこそ。
