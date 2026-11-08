# Reddit クローン — ファイルインデックス

---

## チュートリアル

| ファイル | 内容 |
|---------|------|
| [第0章 はじめに](chapter_00.md) | このチュートリアルで作るもの・環境・設計思想 |
| [第1章 セットアップ](chapter_01.md) | Phoenix プロジェクト生成・依存関係・DB設定 |
| [第2章 DB設計（前編）](chapter_02a.md) | テーブル設計の考え方・users〜posts マイグレーション |
| [第2章 DB設計（後編）](chapter_02b.md) | comments〜reports マイグレーション・実行手順 |
| [第3章 スキーマ（前編）](chapter_03a.md) | Ecto とは・User・Subreddit・SubredditMember |
| [第3章 スキーマ（後編）](chapter_03b.md) | Post・Comment・Vote・Report スキーマ |
| [第4章 Context（前編）](chapter_04a.md) | Context パターン・Accounts・Communities |
| [第4章 Context（中編）](chapter_04b.md) | Posts・投票ロジック詳細 |
| [第4章 Context（後編）](chapter_04c.md) | Comments・ツリーアルゴリズム・Reports |
| [第5章 認証（前編）](chapter_05a.md) | セッションの仕組み・UserAuth・SessionController |
| [第5章 認証（後編）](chapter_05b.md) | RegisterLive・LoginLive・Router |
| [第6章 LiveView（前編）](chapter_06a.md) | LiveView とは・SubredditLive・NewSubredditLive |
| [第6章 LiveView（中編）](chapter_06b.md) | NewPostLive・PostLive |
| [第6章 LiveView（後編）](chapter_06c.md) | HomeFeedLive・ProfileLive・SearchLive |
| [第7章 コンポーネント（前編）](chapter_07a.md) | コンポーネントとは・Helpers・PostCard |
| [第7章 コンポーネント（後編）](chapter_07b.md) | CommentTree（再帰）・ReportModal |
| [第8章 仕上げ](chapter_08.md) | ナビゲーションバー・動作確認・よくあるエラー |
| [付録](appendix.md) | ファイル構成一覧・URL対応表・Context関数一覧 |

---

## コード — マイグレーション

| ファイル | 内容 |
|---------|------|
| [create_users](../migrations/20240001000000_create_users.exs) | users テーブル |
| [create_subreddits](../migrations/20240001000001_create_subreddits.exs) | subreddits テーブル |
| [create_subreddit_members](../migrations/20240001000002_create_subreddit_members.exs) | subreddit_members テーブル |
| [create_posts](../migrations/20240001000003_create_posts.exs) | posts テーブル |
| [create_comments](../migrations/20240001000004_create_comments.exs) | comments テーブル |
| [create_votes](../migrations/20240001000005_create_votes.exs) | votes テーブル |
| [create_reports](../migrations/20240001000006_create_reports.exs) | reports テーブル |

---

## コード — Ecto スキーマ

| ファイル | モジュール |
|---------|-----------|
| [user.ex](../schemas/user.ex) | RedditClone.Accounts.User |
| [subreddit.ex](../schemas/subreddit.ex) | RedditClone.Communities.Subreddit |
| [subreddit_member.ex](../schemas/subreddit_member.ex) | RedditClone.Communities.SubredditMember |
| [post.ex](../schemas/post.ex) | RedditClone.Posts.Post |
| [comment.ex](../schemas/comment.ex) | RedditClone.Comments.Comment |
| [vote.ex](../schemas/vote.ex) | RedditClone.Posts.Vote |
| [report.ex](../schemas/report.ex) | RedditClone.Reports.Report |

---

## コード — Context（ビジネスロジック）

| ファイル | モジュール |
|---------|-----------|
| [accounts.ex](../contexts/accounts.ex) | RedditClone.Accounts |
| [communities.ex](../contexts/communities.ex) | RedditClone.Communities |
| [posts.ex](../contexts/posts.ex) | RedditClone.Posts |
| [comments.ex](../contexts/comments.ex) | RedditClone.Comments |
| [reports.ex](../contexts/reports.ex) | RedditClone.Reports |

---

## コード — 認証

| ファイル | モジュール |
|---------|-----------|
| [user_auth.ex](../auth/user_auth.ex) | RedditCloneWeb.UserAuth |
| [session_controller.ex](../auth/session_controller.ex) | RedditCloneWeb.SessionController |
| [register_live.ex](../auth/register_live.ex) | RedditCloneWeb.RegisterLive |
| [login_live.ex](../auth/login_live.ex) | RedditCloneWeb.LoginLive |
| [router.ex](../auth/router.ex) | RedditCloneWeb.Router |

---

## コード — LiveView（画面）

| ファイル | モジュール |
|---------|-----------|
| [home_feed_live.ex](../live/home_feed_live.ex) | RedditCloneWeb.HomeFeedLive |
| [subreddit_live.ex](../live/subreddit_live.ex) | RedditCloneWeb.SubredditLive |
| [new_subreddit_live.ex](../live/new_subreddit_live.ex) | RedditCloneWeb.NewSubredditLive |
| [post_live.ex](../live/post_live.ex) | RedditCloneWeb.PostLive |
| [new_post_live.ex](../live/new_post_live.ex) | RedditCloneWeb.NewPostLive |
| [profile_live.ex](../live/profile_live.ex) | RedditCloneWeb.ProfileLive |
| [search_live.ex](../live/search_live.ex) | RedditCloneWeb.SearchLive |

---

## コード — コンポーネント

| ファイル | モジュール |
|---------|-----------|
| [helpers.ex](../live/helpers.ex) | RedditCloneWeb.Helpers |
| [post_card.ex](../live/components/post_card.ex) | RedditCloneWeb.Components.PostCard |
| [comment_tree.ex](../live/components/comment_tree.ex) | RedditCloneWeb.Components.CommentTree |
| [report_modal.ex](../live/components/report_modal.ex) | RedditCloneWeb.Components.ReportModal |
| [root.html.heex](../live/root.html.heex) | ナビゲーションバー（レイアウト） |

---

## 合計

```
チュートリアル  18ファイル
マイグレーション  7ファイル
スキーマ          7ファイル
Context           5ファイル
認証              5ファイル
LiveView          7ファイル
コンポーネント    5ファイル
─────────────────────────
合計             59ファイル
```
