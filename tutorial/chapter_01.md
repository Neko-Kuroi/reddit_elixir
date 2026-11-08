# 第1章　プロジェクトのセットアップ

---

## 1-1　Phoenix プロジェクトを生成する

まずターミナルで以下のコマンドを実行してください。

```bash
mix phx.new reddit_clone --database postgres
```

いくつか質問されます。

```
Fetch and install dependencies? [Yn]
```

`Y` を入力して Enter を押してください。依存ライブラリが自動的にインストールされます。

生成が完了したら、プロジェクトディレクトリに移動します。

```bash
cd reddit_clone
```

---

### 生成されるディレクトリ構造

```
reddit_clone/
  ├─ lib/
  │   ├─ reddit_clone/           ← ビジネスロジック（Context・スキーマ）
  │   └─ reddit_clone_web/       ← Web 層（LiveView・Router・コンポーネント）
  │
  ├─ priv/
  │   └─ repo/
  │       └─ migrations/         ← マイグレーションファイルをここに置く
  │
  ├─ test/                       ← テスト
  ├─ config/                     ← 設定ファイル
  └─ mix.exs                     ← 依存関係の定義
```

`lib/reddit_clone/` と `lib/reddit_clone_web/` の2つに分かれているのがポイントです。この分離が第0章で説明した「3層構造」を実現します。

---

## 1-2　依存関係を追加する

`mix.exs` を開き、`deps` 関数にパスワードハッシュ化ライブラリを追加します。

```elixir
# mix.exs
defp deps do
  [
    {:phoenix, "~> 1.7"},
    {:phoenix_ecto, "~> 4.4"},
    {:ecto_sql, "~> 3.10"},
    {:postgrex, ">= 0.0.0"},
    {:phoenix_html, "~> 4.0"},
    {:phoenix_live_view, "~> 0.20"},
    {:phoenix_live_reload, "~> 1.2", only: :dev},

    # ↓ この行を追加する
    {:bcrypt_elixir, "~> 3.0"},

    {:tailwind, "~> 0.2", only: :dev},
    {:esbuild, "~> 0.8", only: :dev},
    {:swoosh, "~> 1.3"},
    {:finch, "~> 0.13"},
    {:telemetry_metrics, "~> 0.6"},
    {:telemetry_poller, "~> 1.0"},
    {:jason, "~> 1.2"},
    {:dns_cluster, "~> 0.1.1"},
    {:bandit, "~> 1.2"}
  ]
end
```

`bcrypt_elixir` はパスワードをハッシュ化するライブラリです。パスワードをそのまま DB に保存することは絶対にしてはいけません。このライブラリが安全なハッシュ化を担当します。

追加したら依存関係をインストールします。

```bash
mix deps.get
```

---

## 1-3　データベースを設定する

`config/dev.exs` を開いて、PostgreSQL の接続情報を確認・修正します。

```elixir
# config/dev.exs
config :reddit_clone, RedditClone.Repo,
  username: "postgres",    # PostgreSQL のユーザー名
  password: "postgres",    # PostgreSQL のパスワード
  hostname: "localhost",
  database: "reddit_clone_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10
```

ローカルの PostgreSQL の設定に合わせて `username` と `password` を変更してください。

設定が完了したら、データベースを作成します。

```bash
mix ecto.create
```

成功すると以下のように表示されます。

```
The database for RedditClone.Repo has been created
```

---

## 1-4　ディレクトリを整理する

これから作るファイルのために、以下のディレクトリ構造を用意します。

```bash
# スキーマの置き場所
mkdir -p lib/reddit_clone/accounts
mkdir -p lib/reddit_clone/communities
mkdir -p lib/reddit_clone/posts
mkdir -p lib/reddit_clone/comments
mkdir -p lib/reddit_clone/reports

# Web 層の置き場所
mkdir -p lib/reddit_clone_web/live/components
mkdir -p lib/reddit_clone_web/controllers
```

各ディレクトリの役割は以下の通りです。

| ディレクトリ | 役割 |
|-------------|------|
| `accounts/` | User スキーマ |
| `communities/` | Subreddit・SubredditMember スキーマ |
| `posts/` | Post・Vote スキーマ |
| `comments/` | Comment スキーマ |
| `reports/` | Report スキーマ |
| `live/components/` | 再利用可能な UI コンポーネント |
| `controllers/` | SessionController |

Context のファイル（`accounts.ex`・`communities.ex` など）は `lib/reddit_clone/` 直下に置きます。

---

## 1-5　動作確認

サーバーを起動して、Phoenix のデフォルト画面が表示されるか確認します。

```bash
mix phx.server
```

ブラウザで `http://localhost:4000` を開いてください。Phoenix のウェルカムページが表示されれば成功です。

```
[info] Running RedditCloneWeb.Endpoint with Bandit 1.x
[info] Access RedditCloneWeb.Endpoint at http://localhost:4000
```

確認できたら `Ctrl + C` でサーバーを停止します。

---

## 1-6　Repo の設定を確認する

`lib/reddit_clone/repo.ex` が自動生成されています。内容を確認してください。

```elixir
# lib/reddit_clone/repo.ex
defmodule RedditClone.Repo do
  use Ecto.Repo,
    otp_app: :reddit_clone,
    adapter: Ecto.Adapters.Postgres
end
```

このモジュールがアプリ全体のデータベース操作の窓口になります。Context からは必ずこの `Repo` を通してデータベースにアクセスします。

---

## まとめ

この章では以下を完了しました。

```
✅ Phoenix プロジェクトの生成
✅ bcrypt_elixir の追加
✅ データベースの作成
✅ ディレクトリ構造の準備
✅ 動作確認
```

次の章では、アプリの土台となるデータベースのテーブル設計を行います。どのようなテーブルが必要で、それぞれがどう関係しているかを考えてから、マイグレーションファイルを実装します。
