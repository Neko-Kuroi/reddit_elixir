# 全コード付録 4　設定（mix.exs と第1章で扱う生成ファイル）

> **このファイルは自動生成です。** 生成スクリプト `~/workspace/reddit_clone_audit/generate_code_appendix.py` が、
> 正本のコードファイル（`~/workspace/reddit_clone_fixed/` 内）から全文を機械的に転記して作りました。
> **正本はコードファイルそのもの**であり、この付録は「すべてのコードがチュートリアル側に収録されている」
> ことを保証するための再録です。コードを直すときは正本を直し、この付録は再生成してください。
>
> 対応する章: 第1章（セットアップ）

---

## mix.exs（プロジェクト設定・全文）

対応: 第1章 1-2。正本: `mix.exs`

```elixir
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

      # パスワードハッシュ化 ← 手動で追加が必要な唯一の依存関係
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

## 第1章で扱う自動生成ファイル（本文掲載分）

以下の2つは `mix phx.new` が自動生成するファイルで、正本のコード一式（fixed 版）には含まれていません。第1章の本文に載っている分を、そのまま転記します。**dev.exs は本文掲載分のみ**で、生成される dev.exs 全文ではありません（未収録部分があることに注意）。

### lib/reddit_clone/repo.ex（第1章 1-6・全文）

```elixir
# lib/reddit_clone/repo.ex
defmodule RedditClone.Repo do
  use Ecto.Repo,
    otp_app: :reddit_clone,
    adapter: Ecto.Adapters.Postgres
end
```

### config/dev.exs（第1章 1-3・Repo 設定の部分のみ）

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
