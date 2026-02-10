# Paper Writing System

論文執筆用のマルチエージェントフレームワーク。

## クイックスタート

### 必要なもの

- **tmux**: `brew install tmux` (macOS) / `sudo apt install tmux` (Linux)
- **Claude Code CLI**: [claude.ai/code](https://claude.ai/code)（`claude auth login` 必須）
- **Mac 初回セットアップ**: [docs/setup-mac.md](docs/setup-mac.md)

### 起動

```bash
# ターミナルのみ
./start.sh

# Webブラウザ版（推奨）
./start.sh --web
```

### 使い方（最短）

1. Authorに **Q&A** + **保存先セクション** を送る
2. Authorがドラフト作成
3. **OK** → レビュー＆リバッタルが自動で完了

**入力例**:
```
Q: Why does our method outperform?
A: Because of X, Y, Z
section: method
```

**複数 Q&A（バッチ）**:
```
Q: ...
A: ...
section: introduction
---
Q: ...
A: ...
section: method
```

---

## 2つのモード（起動コマンド）

| モード | コマンド | 説明 |
|--------|----------|------|
| **ターミナル版** | `./start.sh` | tmuxセッションに直接アクセス |
| **Webブラウザ版** | `./start.sh --web` | ブラウザで全て完結（推奨） |

👉 **詳細**: [docs/web-dashboard.md](docs/web-dashboard.md)

---

## コマンド一覧

### 起動オプション

```bash
./start.sh                    # ターミナルのみ
./start.sh --web              # Web版を起動
./start.sh --web -m sonnet    # Sonnetモデルで起動
./start.sh -c                 # 状態をリセットして起動
./start.sh -h                 # ヘルプ表示
```

### ユーザー介入コマンド

`OK` / `PAUSE` / `redirect: [指示]` / `skip reviewer N` / `habit: [好み]`

### Webサーバー操作

```bash
# 停止
pkill -f "server.py --port 5050"

# 再起動
pkill -f "server.py --port 5050"; sleep 1
cd web && uv run python server.py --port 5050 &
```

---

## ファイル構成（抜粋）

```
paper-writing-system/
├── instructions/        # エージェントへの指示
│   ├── author.md
│   └── reviewer.md
├── context/             # 一貫性チェック用ファイル
│   ├── author_habits.yaml   # Authorの癖リスト
│   ├── glossary.yaml        # 用語・記法の辞書
│   └── references.md        # 参考英文（ペースト用）
├── paper/               # 論文ファイル
│   ├── main.tex
│   └── sections/
├── queue/               # エージェント間通信
├── config/settings.yaml # 設定
├── web/                 # Webダッシュボード
└── docs/                # 詳細ドキュメント
```

---

## ドキュメント

| ファイル | 内容 |
|----------|------|
| [docs/web-dashboard.md](docs/web-dashboard.md) | Webブラウザ版の詳細 |
| [docs/commands.md](docs/commands.md) | 全コマンドリファレンス |
| [CLAUDE.md](CLAUDE.md) | システム設計・エージェント向け情報 |

---

## ライセンス

MIT License
