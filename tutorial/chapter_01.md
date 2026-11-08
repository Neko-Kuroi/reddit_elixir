# 第1章　プロジェクトのセットアップ

---

### この章で学ぶこと

- 作るもの: Phoenix プロジェクト本体、依存関係の定義（`mix.exs`）、データベース接続の設定、これから作るファイルのためのディレクトリ
- 学ぶ考え方: Mix プロジェクトの構造、`mix.exs` の読み方（`project` / `application` / `deps` / `aliases`）、バージョン指定 `~>` の意味、設定ファイル（config）の役割、Repo の位置づけ

### 前提

- 第0章「必要な環境」のチェックリストが済んでいること（Elixir 1.14 以上、Erlang 25 以上、PostgreSQL 14 以上、Node.js 18 以上）
- ターミナルでコマンドを実行できること

### 全体の中での位置

この章は、3層構造そのものを作る章ではありません。Web 層・Context 層・Data 層の3層がこれから入る「入れ物」を用意する章です。ただし、データベースの窓口である Repo と接続設定は Data 層の土台にあたります。

なお、この章で扱う `mix.exs` の全文は、巻末の全コード付録 4（appendix_code_04）に収録しています。本文では、意味のまとまりごとに分けて読み解きます。

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

**読み解き**

ここで、Elixir の基本の言葉を2つだけ先にそろえます。

- **モジュール** — 関数をまとめた入れ物です。`defmodule` で定義します。このあと出てくるファイルは、どれもモジュール1つ（または複数）からできています
- **関数** — 処理のまとまりです。`def` で定義するのが外から呼べる関数、`defp` で定義するのがそのモジュールの中だけで使う関数です

`lib/reddit_clone/` 側のモジュールは `RedditClone.` で始まる名前、`lib/reddit_clone_web/` 側は `RedditCloneWeb.` で始まる名前を持ちます。名前の前半を見れば、そのコードがどちらの側（ビジネスロジック側か、Web 側か）がすぐに分かる、という約束です。第3章以降でファイルが増えても、この約束で迷子になりません。

---

## 1-2　依存関係を追加する

`mix.exs` を開き、`deps` 関数にパスワードハッシュ化ライブラリを追加します。

```elixir
# mix.exs（deps の全文。生成直後の状態に bcrypt_elixir を加えた完成形）
defp deps do
  [
    # Phoenix 本体
    {:phoenix, "~> 1.7"},
    {:phoenix_ecto, "~> 4.4"},
    {:ecto_sql, "~> 3.10"},
    {:postgrex, ">= 0.0.0"},
    {:phoenix_html, "~> 4.0"},
    {:phoenix_live_view, "~> 0.20"},
    {:phoenix_live_reload, "~> 1.2", only: :dev},

    # パスワードハッシュ化 ← 手動で追加が必要な唯一の依存関係（この行を足す）
    {:bcrypt_elixir, "~> 3.0"},

    # アセットビルド
    {:tailwind, "~> 0.2", only: :dev},
    {:esbuild, "~> 0.8", only: :dev},
    {:heroicons,
     github: "tailwindlabs/heroicons",
     tag: "v2.1.1",
     sparse: "optimized",
     app: false,
     compile: false,
     depth: 1},

    # メール送信（Phoenix デフォルト）
    {:swoosh, "~> 1.3"},
    {:finch, "~> 0.13"},

    # テレメトリー・監視
    {:telemetry_metrics, "~> 0.6"},
    {:telemetry_poller, "~> 1.0"},

    # JSON
    {:jason, "~> 1.2"},

    # クラスタリング
    {:dns_cluster, "~> 0.1.1"},

    # Webサーバー
    {:bandit, "~> 1.2"},

    # テスト
    {:floki, ">= 0.30.0", only: :test}
  ]
end
```

`bcrypt_elixir` はパスワードをハッシュ化するライブラリです。パスワードをそのまま DB に保存することは絶対にしてはいけません。このライブラリが安全なハッシュ化を担当します。生成直後の状態との違いは、この `bcrypt_elixir` の1行だけです。

そのほかの行で、形が他と違うものを2つだけ見ておきます。

- `heroicons` は、アイコン画像の集まりを GitHub から取得する指定です。バージョンの条件ではなく `github:` と `tag:` で取得先を指している点が、ほかの行と違います。このアプリで自分が書くコードには直接出てきません
- `floki` は、テストのときだけ使う HTML の読み取りライブラリです。名前を聞き覚えがなくても心配いりません。使うのはテストを書くときだけです

**読み解き**

`deps` の1行は、名前と条件を組にした形（タプル）になっています。たとえば `{:phoenix, "~> 1.7"}` は「名前は phoenix、バージョンの条件は "~> 1.7"」という意味です。

バージョン指定 `"~> 1.7"` の読み方が、この節でいちばん大切です。これは「1.7 以上、2.0 未満」という意味です。細かい改善は取り込むが、大きな節目の変更までは取り込まない、という指定のしかたです。`"~> 0.20"` なら「0.20 以上、1.0 未満」、`">= 0.0.0"` なら「どのバージョンでもよい」になります。

行の後ろに付く `only: :dev` は「開発環境でのみ使う」、`only: :test` は「テスト環境でのみ使う」という限定です。本番で要らないものを本番に混ぜないための書き分けです。

間違えやすいのは、`mix.exs` を書き換えただけでは何も入らないことです。次の `mix deps.get` を実行して、初めて実際に取得されます。

追加したら依存関係をインストールします。

```bash
mix deps.get
```

---

### mix.exs の全体像

`deps` 以外の部分も、この機会に全体を見ておきます。`mix.exs` は1つのモジュール（`RedditClone.MixProject`）でできていて、中身は「プロジェクトの定義」「アプリの起動の定義」「コンパイル対象の場所」「依存関係」「別名コマンド（aliases）」の5つの部品です。全文は全コード付録 4（appendix_code_04）に収録しています。ここでは部品ごとに全文を載せます。

まず、プロジェクトの定義と、アプリの起動の定義です。

```elixir
# mix.exs（冒頭〜 application まで）
defmodule RedditClone.MixProject do
  use Mix.Project

  def project do
    [
      app: :reddit_clone,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      mod: {RedditClone.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # テスト環境のみ test/support を含める
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]
```

**読み解き**

`project/0` は、プロジェクトの名札です。`app:` がアプリの名前、`elixir:` が必要な Elixir のバージョン（ここでも `~>` が出てきました）、`deps: deps()` は「依存関係は `deps` 関数の戻り値を使う」という意味です。角かっこで囲まれた `app: :reddit_clone` のような並びは、キーワードリストと呼ばれる「名前と値の組の並び」で、Elixir では設定や選択肢を渡すときによく使われます。

`application/0` の `mod:` は、アプリ起動時に最初に呼ばれるモジュール（`RedditClone.Application`）を指定します。このモジュールは phx.new が自動生成するもので、データベースや Web の窓口の起動を見守ります。今は「起動の起点がここに書かれている」ことだけ分かれば十分です。

`elixirc_paths/1` は、同じ名前の関数が2つある例です。Elixir では、引数の形（パターン）によって、どの関数が呼ばれるかが決まります。`:test` という決まった値が来たときだけ `test/support` を含め、それ以外は `lib` だけ、という書き分けです。この「引数の形で振り分ける」書き方は、第4章で何度も出てきます。

次に、別名コマンド（aliases）です。

```elixir
# mix.exs（aliases の全文）
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind reddit_clone", "esbuild reddit_clone"],
      "assets.deploy": [
        "tailwind reddit_clone --minify",
        "esbuild reddit_clone --minify",
        "phx.digest"
      ]
    ]
  end
end
```

**読み解き**

aliases は「長い手順に短い名前を付ける」仕組みです。たとえば `mix setup` と打つと、`deps.get`（依存関係の取得）から画面部品の用意までが順番に実行されます。`ecto.reset` は「データベースを捨てて、作り直して、マイグレーションを流す」というやり直しの手順で、第2章でマイグレーションを直すときに使います。

ここで大切なのは、`mix.exs` は「設定を書くファイルであると同時に、Elixir のプログラムそのもの」だという見方です。だからこそ、関数の形で部品が分かれ、条件で振り分ける書き方ができるのです。

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

**読み解き**

設定ファイル（config）は、「プログラムの動きを決める値を、コードの外に置く」ための場所です。`config :reddit_clone, RedditClone.Repo, ...` は「reddit_clone というアプリの、Repo というモジュールに対して、この値を渡す」という意味で、値の並びは mix.exs で見たキーワードリストと同じ形です。

設定ファイルは環境ごとに分かれています。全体共通の `config/config.exs`、開発用の `config/dev.exs`、本番用の `config/prod.exs`、テスト用の `config/test.exs` です。今触っているのは開発用です。開発用の接続先と本番用の接続先を混ぜないための仕組みだと考えてください。

気をつける点が1つあります。開発用のファイルにパスワードをそのまま書くのは、自分のパソコンの中だけの話だから許されますが、本番の秘密の値をファイルに書いて公開してはいけません。本番では、環境変数（プログラムの外から渡す値）から読むのが決まりです。この本では本番運用までは扱いませんが、線引きだけ覚えておいてください。

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

**読み解き**

Repo はたった6行ですが、この先ずっと出てくる大切な部品です。読み解くと、`use Ecto.Repo` は「Ecto.Repo の機能をこのモジュールに取り込む」という宣言、`otp_app: :reddit_clone` は「設定は reddit_clone というアプリの分を読む」という指定、`adapter: Ecto.Adapters.Postgres` は「接続先のデータベースは PostgreSQL」という指定です。1-3 で書いた接続情報は、この `otp_app` の指定を通じて Repo に届きます。

なぜ窓口を1つに決めるのかというと、接続先の変更や、データベースの使い方の共通ルールを、1か所で管理できるからです。第4章の Context は、すべてこの Repo を通して読み書きします。

---

## 動作確認（この章の仕上げ）

1-5 の確認に加えて、この章の終わりに次を確かめてください。前提は、PostgreSQL が起動していることです。

- [ ] `mix deps.get` がエラーなく終わり、`bcrypt_elixir` が取得されている
- [ ] `mix ecto.create` で「The database for RedditClone.Repo has been created」と表示される（すでに作られている場合は、その旨の表示でも構いません）
- [ ] `mix phx.server` でサーバーが起動し、`http://localhost:4000` に Phoenix の画面が出る
- [ ] `lib/reddit_clone/` と `lib/reddit_clone_web/` の下に、1-4 のディレクトリができている
- [ ] 確認が終わったら `Ctrl + C` でサーバーを止める

---

## よくあるエラーと対処

| 症状 | 原因 | 直し方 |
|------|------|--------|
| `mix phx.new` が「コマンドが見つからない」になる | Phoenix の生成器が未インストール | `mix archive.install hex phx_new` を実行してから、もう一度試す |
| `mix deps.get` で取得に失敗する | ネットワークの問題、または Hex の初期設定が未完了 | 表示された案内に従い `mix local.hex` などを実行し、もう一度 `mix deps.get` する |
| `mix ecto.create` で接続エラーになる | PostgreSQL が起動していない、または `config/dev.exs` のユーザー名・パスワードが違う | PostgreSQL の起動を確認し、1-3 の接続情報を自分の環境に合わせる |
| サーバー起動時に「ポート 4000 は使用中」と出る | 前のサーバーが止まっていない、または別のアプリが使っている | 前のサーバーを `Ctrl + C` で止める。それでも出る場合は、使っているアプリを止める |

---

## 確認問題

1. `{:phoenix, "~> 1.7"}` の `"~> 1.7"` は、バージョンの範囲としてどういう意味ですか。
2. `mix.exs` の `deps` に行を足しただけでは、なぜライブラリは使えるようにならないのですか。
3. `config/dev.exs` と `config/prod.exs` のように、設定ファイルが環境ごとに分かれている理由は何ですか。
4. 第4章の Context がデータベースを読み書きするとき、必ず通る窓口の名前は何ですか。また、その窓口が「接続先は PostgreSQL」と知る手がかりは、どこに書かれていますか。

---

## まとめと次章へのつながり

この章では以下を完了しました。

```
✅ Phoenix プロジェクトの生成
✅ bcrypt_elixir の追加
✅ データベースの作成
✅ ディレクトリ構造の準備
✅ 動作確認
```

次の章では、アプリの土台となるデータベースのテーブル設計を行います。どのようなテーブルが必要で、それぞれがどう関係しているかを考えてから、マイグレーションファイルを実装します。そのときに使うのが、この章で用意した Repo と、この章で作成したデータベースです。

---

## 確認問題の答え

1. 「1.7 以上、2.0 未満」という意味です。細かい更新は取り込むが、大きな節目の変更は取り込まない指定です。
2. `deps` への記述は「必要なものの一覧」を宣言しただけだからです。`mix deps.get` を実行して、実際に取得されて初めて使えます。
3. 開発・本番・テストで、接続先や秘密の値の扱いが違うからです。混ぜて書くと、本番の接続先を開発で使ってしまうような事故のもとになります。
4. 窓口は `RedditClone.Repo` です。手がかりは `repo.ex` の `adapter: Ecto.Adapters.Postgres` という指定です。接続情報そのものは、`otp_app: :reddit_clone` を通じて設定ファイル側から届きます。
