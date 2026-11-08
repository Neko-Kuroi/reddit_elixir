# 付録　ファイル構成一覧

---

## 完成時のディレクトリ構造

```
reddit_clone/
  │
  ├─ lib/
  │   │
  │   ├─ reddit_clone/                      ← ビジネスロジック層
  │   │   ├─ repo.ex                        ← DB の窓口（自動生成）
  │   │   │
  │   │   ├─ accounts.ex                    ← Accounts Context
  │   │   ├─ communities.ex                 ← Communities Context
  │   │   ├─ posts.ex                       ← Posts Context
  │   │   ├─ comments.ex                    ← Comments Context
  │   │   ├─ reports.ex                     ← Reports Context
  │   │   │
  │   │   ├─ accounts/
  │   │   │   └─ user.ex                    ← User スキーマ
  │   │   │
  │   │   ├─ communities/
  │   │   │   ├─ subreddit.ex               ← Subreddit スキーマ
  │   │   │   └─ subreddit_member.ex        ← SubredditMember スキーマ
  │   │   │
  │   │   ├─ posts/
  │   │   │   ├─ post.ex                    ← Post スキーマ
  │   │   │   └─ vote.ex                    ← Vote スキーマ
  │   │   │
  │   │   ├─ comments/
  │   │   │   └─ comment.ex                 ← Comment スキーマ
  │   │   │
  │   │   └─ reports/
  │   │       └─ report.ex                  ← Report スキーマ
  │   │
  │   └─ reddit_clone_web/                  ← Web 層
  │       ├─ router.ex                      ← ルーティング
  │       ├─ user_auth.ex                   ← 認証 Plug・on_mount
  │       │
  │       ├─ controllers/
  │       │   └─ session_controller.ex      ← ログイン・ログアウト
  │       │
  │       ├─ live/
  │       │   ├─ helpers.ex                 ← 共通ヘルパー関数
  │       │   ├─ home_feed_live.ex          ← ホーム Feed
  │       │   ├─ subreddit_live.ex          ← コミュニティページ
  │       │   ├─ new_subreddit_live.ex      ← コミュニティ作成
  │       │   ├─ post_live.ex               ← 投稿詳細
  │       │   ├─ new_post_live.ex           ← 投稿作成
  │       │   ├─ profile_live.ex            ← プロフィール
  │       │   ├─ search_live.ex             ← 検索
  │       │   ├─ register_live.ex           ← ユーザー登録
  │       │   ├─ login_live.ex              ← ログイン
  │       │   │
  │       │   └─ components/
  │       │       ├─ post_card.ex           ← 投稿カードコンポーネント
  │       │       ├─ comment_tree.ex        ← コメントツリーコンポーネント
  │       │       └─ report_modal.ex        ← 報告モーダルコンポーネント
  │       │
  │       └─ components/
  │           └─ layouts/
  │               └─ root.html.heex         ← ナビゲーションバー
  │
  ├─ priv/
  │   └─ repo/
  │       └─ migrations/
  │           ├─ XXXXXX_create_users.exs
  │           ├─ XXXXXX_create_subreddits.exs
  │           ├─ XXXXXX_create_subreddit_members.exs
  │           ├─ XXXXXX_create_posts.exs
  │           ├─ XXXXXX_create_comments.exs
  │           ├─ XXXXXX_create_votes.exs
  │           └─ XXXXXX_create_reports.exs
  │
  ├─ config/
  │   ├─ config.exs
  │   ├─ dev.exs                            ← DB 接続設定
  │   ├─ prod.exs
  │   └─ test.exs
  │
  └─ mix.exs                                ← 依存関係
```

---

## ファイルと章の対応表

| ファイル | 実装した章 |
|---------|-----------|
| `priv/repo/migrations/*.exs` | 第2章 |
| `accounts/user.ex` | 第3章 |
| `communities/subreddit.ex` | 第3章 |
| `communities/subreddit_member.ex` | 第3章 |
| `posts/post.ex` | 第3章 |
| `posts/vote.ex` | 第3章 |
| `comments/comment.ex` | 第3章 |
| `reports/report.ex` | 第3章 |
| `accounts.ex` | 第4章 |
| `communities.ex` | 第4章 |
| `posts.ex` | 第4章 |
| `comments.ex` | 第4章 |
| `reports.ex` | 第4章 |
| `user_auth.ex` | 第5章 |
| `session_controller.ex` | 第5章 |
| `router.ex` | 第5章 |
| `register_live.ex` | 第5章 |
| `login_live.ex` | 第5章 |
| `subreddit_live.ex` | 第6章 |
| `new_subreddit_live.ex` | 第6章 |
| `new_post_live.ex` | 第6章 |
| `post_live.ex` | 第6章 |
| `home_feed_live.ex` | 第6章 |
| `profile_live.ex` | 第6章 |
| `search_live.ex` | 第6章 |
| `helpers.ex` | 第7章 |
| `components/post_card.ex` | 第7章 |
| `components/comment_tree.ex` | 第7章 |
| `components/report_modal.ex` | 第7章 |
| `layouts/root.html.heex` | 第8章 |

---

## URL とページの対応表

| URL | LiveView | 認証 |
|-----|---------|------|
| `/` | HomeFeedLive | 必須 |
| `/register` | RegisterLive | ログイン済みはリダイレクト |
| `/login` | LoginLive | ログイン済みはリダイレクト |
| `/subreddits/new` | NewSubredditLive | 必須 |
| `/r/:name` | SubredditLive | 不要 |
| `/r/:name/submit` | NewPostLive | 必須 |
| `/r/:name/:post_id` | PostLive | 不要 |
| `/u/:username` | ProfileLive | 不要 |
| `/search` | SearchLive | 不要 |
| `GET /session` | SessionController | — |
| `DELETE /logout` | SessionController | — |

---

## Context の関数一覧

### Accounts

| 関数 | 説明 |
|------|------|
| `change_user_registration/1` | 空のチェンジセットを返す（フォーム初期化用） |
| `register_user/1` | ユーザーを登録する |
| `login_user/2` | メールとパスワードでログインする |
| `get_user_by_username/1` | username でユーザーを取得する |
| `get_user!/1` | id でユーザーを取得する |
| `update_karma/3` | Karma を増減する |

### Communities

| 関数 | 説明 |
|------|------|
| `create_subreddit/1` | コミュニティを作成する（moderator 登録含む） |
| `get_subreddit_by_name/1` | name でコミュニティを取得する |
| `get_subreddit!/1` | id でコミュニティを取得する |
| `list_joined_subreddits/1` | 参加済みコミュニティ一覧を返す |
| `join_subreddit/2` | コミュニティに参加する |
| `leave_subreddit/2` | コミュニティから脱退する |
| `member?/2` | 参加済みかどうかを確認する |
| `moderator?/2` | モデレーターかどうかを確認する |
| `search_subreddits/1` | キーワードでコミュニティを検索する |

### Posts

| 関数 | 説明 |
|------|------|
| `create_post/1` | 投稿を作成する |
| `get_post/1` | id で投稿を取得する |
| `get_post!/1` | id で投稿を取得する（なければ例外） |
| `list_posts/3` | コミュニティの投稿一覧を取得する |
| `list_home_posts/3` | ホーム Feed の投稿一覧を取得する |
| `list_user_posts/2` | ユーザーの投稿一覧を取得する |
| `vote_post/3` | 投稿に投票する |
| `delete_post/3` | 投稿を削除する |
| `search_posts/1` | キーワードで投稿を検索する |

### Comments

| 関数 | 説明 |
|------|------|
| `create_comment/1` | コメントを作成する |
| `list_comments/1` | 投稿のコメントをツリー構造で取得する |
| `vote_comment/3` | コメントに投票する |
| `delete_comment/3` | コメントを削除する |
| `get_comment!/1` | id でコメントを取得する |

### Reports

| 関数 | 説明 |
|------|------|
| `create_report/1` | 報告を作成する |
