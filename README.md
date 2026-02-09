# Paper Writing System

論文執筆のためのマルチエージェントフレームワーク。1人のAuthorと3人のReviewerが厳格なレビューサイクルを通じて高品質なパラグラフを生成します。

## クイックスタート

### 必要なもの

- **tmux**: `brew install tmux` (macOS) / `sudo apt install tmux` (Linux)
- **Claude Code CLI**: [claude.ai/code](https://claude.ai/code)

### 起動

```bash
# ターミナルのみ
./start.sh

# Webブラウザ版（推奨）
./start.sh --web
```

### 使い方

1. Authorに **question**（何を説明するか）と **answer**（技術的情報）を伝える
2. Authorがドラフトを作成
3. **OK** と言ってレビュー開始
4. 3人のReviewerがレビュー → Authorが修正 → 全員承認まで繰り返し
5. 承認後、保存先を指定

---

## 2つのモード

| モード | コマンド | 説明 |
|--------|----------|------|
| **ターミナル版** | `./start.sh` | tmuxセッションに直接アクセス |
| **Webブラウザ版** | `./start.sh --web` | ブラウザで全て完結（推奨） |

### Webブラウザ版の利点

- 🖥️ tmuxにアタッチ不要（ブラウザだけで操作可能）
- 📊 4エージェントの出力をリアルタイム表示
- 🔔 ユーザー入力待ちを通知（音・ブラウザ通知）
- 🤖 モデル切り替え（Opus/Sonnet）
- ⌨️ クイックボタンで簡単入力

👉 **詳細**: [docs/web-dashboard.md](docs/web-dashboard.md)

---

## Reviewer の役割

| Reviewer | 専門 | チェック内容 |
|----------|------|--------------|
| Reviewer 1 | Claims | 新規性、過大主張、先行研究との差別化 |
| Reviewer 2 | Technical | 技術的正確性、再現性、実験設計 |
| Reviewer 3 | Language | 文章の明瞭さ、AI臭い英語の検出 |

**全員共通**: 数式の厳密性、用語・記法の一貫性、論理の流れ

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

### ユーザー介入コマンド（Author実行中に使用）

| コマンド | 効果 |
|----------|------|
| `OK` | ドラフトを承認してレビューへ |
| `yes` | rebuttalを続行 |
| `PAUSE` | 即座に停止して待機 |
| `redirect: [指示]` | Authorの方向性を変更 |
| `skip reviewer N` | Reviewer Nのコメントを無視 |
| `habit: [好み]` | 書き方の好みを追加 |

### Webサーバー操作

```bash
# 停止
pkill -f "server.py --port 5000"

# 再起動
pkill -f "server.py --port 5000"; sleep 1
cd web && uv run python server.py --port 5000 &
```

---

## ファイル構成

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
