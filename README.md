# Paper Writing System

論文執筆用のマルチエージェントフレームワーク。

## クイックスタート

### 1. 依存ツールのインストール

<table>
<tr><th></th><th>macOS</th><th>Ubuntu / Debian</th><th>Windows (WSL2)</th></tr>
<tr>
  <td><strong>tmux</strong></td>
  <td><code>brew install tmux</code></td>
  <td><code>sudo apt install tmux</code></td>
  <td>WSL2 内で <code>sudo apt install tmux</code></td>
</tr>
<tr>
  <td><strong>Python 3</strong></td>
  <td><code>brew install python3</code></td>
  <td><code>sudo apt install python3</code></td>
  <td>WSL2 内で <code>sudo apt install python3</code></td>
</tr>
<tr>
  <td><strong>uv</strong></td>
  <td colspan="3"><code>curl -LsSf https://astral.sh/uv/install.sh | sh</code></td>
</tr>
<tr>
  <td><strong>Claude Code CLI</strong></td>
  <td colspan="3"><a href="https://claude.ai/code">claude.ai/code</a> の手順に従いインストール</td>
</tr>
</table>

> **Windows**: WSL2 が必須です。PowerShell / cmd では動作しません。  
> **macOS 補足**: Homebrew 権限エラーが出る場合は [docs/setup-mac.md](docs/setup-mac.md) を参照。

### 2. Claude Code にログイン

```bash
claude auth login
```

未ログインのまま起動するとエラーになります。

### 3. 起動

```bash
./start.sh --web
```

ブラウザで **http://127.0.0.1:5050** を開いてください。

### 4. 使い方

1. Web UI で **Q&A + 保存先セクション** を入力して Send
2. Author がドラフト作成
3. **OK** を押す → レビュー＆リバッタルが自動で完了

```
Q: Why does our method outperform?
A: Because of X, Y, Z
section: method
```

`section:` を省略すると `paper/drafts.md` に保存。

---

## Web UI 機能

| 機能 | 説明 |
|------|------|
| **Section** | 保存先セクションを選択。「+ new section...」で新規作成 |
| **Model** | Opus / Sonnet を切替 → エージェント自動再起動 |
| **Reset** | 🗑 で全状態リセット（References のみ保持） |
| **通知** | 🔔 で入力待ち時にブラウザ通知 |
| **References** | Context Files タブから参考文を直接編集 |

---

## 起動オプション

```bash
./start.sh --web              # Web版（推奨）
./start.sh                    # ターミナルのみ
./start.sh --web -m sonnet    # Sonnetモデル
./start.sh -c --web           # 状態リセット + 起動
./start.sh --web -p 8080      # ポート指定
./start.sh -h                 # ヘルプ
```

## ユーザーコマンド

| コマンド | 効果 |
|----------|------|
| `OK` | ドラフト承認 → 自動レビュー開始 |
| `PAUSE` | 即時停止 |
| `redirect: [指示]` | リバッタル方向を変更 |
| `skip reviewer N` | Reviewer N をスキップ |
| `habit: [好み]` | 文体の好みを追加 |

---

## ファイル構成

```
├── instructions/           # エージェント指示
├── context/                # 一貫性チェック
│   ├── author_habits.yaml  # 癖リスト（Reset で初期化）
│   ├── glossary.yaml       # 用語辞書（Reset で初期化）
│   └── references.md       # 参考英文（Reset で保持）
├── paper/                  # 論文（Reset で初期化）
├── queue/                  # エージェント間通信（Reset で初期化）
├── config/settings.yaml    # 設定
├── web/                    # Web ダッシュボード
└── CLAUDE.md               # エージェント向け設計情報
```

---

## ライセンス

MIT License
