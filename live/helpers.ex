defmodule RedditCloneWeb.Helpers do
  @moduledoc """
  画面コンポーネント共通のヘルパー関数。
  post_card.ex / comment_tree.ex などから import して使う。
  """

  @doc """
  DateTime を「3時間前」のような相対時間文字列に変換する。

  ## 例
      iex> time_ago(~U[2024-01-01 00:00:00Z])
      "3日前"
  """
  def time_ago(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime)

    cond do
      diff < 60           -> "たった今"
      diff < 3_600        -> "#{div(diff, 60)}分前"
      diff < 86_400       -> "#{div(diff, 3_600)}時間前"
      diff < 86_400 * 30  -> "#{div(diff, 86_400)}日前"
      true                -> "#{div(diff, 86_400 * 30)}ヶ月前"
    end
  end

  @doc """
  URLからドメイン名だけを取り出す。

  ## 例
      iex> domain("https://github.com/elixir-lang/elixir")
      "github.com"

      iex> domain("不正なURL")
      "不正なURL"
  """
  def domain(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{host: host} when is_binary(host) -> host
      _ -> url
    end
  end
  def domain(_), do: ""
end
