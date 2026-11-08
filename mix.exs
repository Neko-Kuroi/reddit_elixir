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
