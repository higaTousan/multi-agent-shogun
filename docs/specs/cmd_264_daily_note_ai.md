# cmd_264 設計書: Obsidianデイリーノート frontmatter AI自動生成

**version**: 1.0
**作成日**: 2026-02-28
**作成者**: 軍師
**ステータス**: 殿レビュー待ち

---

## 1. 概要・目的

Obsidianデイリーノート（`00.Daily/YYYY/YYYY-MM-DD.md`）の frontmatter（`date`・`summary`・`tags`）を、
ローカルOllama（設定ファイルで管理するモデル、評価候補: gemma3:12b）を使って毎日0:15に自動生成するスクリプトとlaunchdジョブを実装する。
gemma3:12bで品質評価を実施し、問題なければ正式採用する。

**解決したい課題**:
- デイリーノートを書いた後、frontmatterの記入が手作業で煩雑
- summaryとtagsは本文を読まないと書けないため、後回しになりがち

**アプローチ**:
- 夜に書いたデイリーノートに対して、翌日0:15に自動でfrontmatterを生成・書き込む
- 既存の値がある場合はスキップ（手書き優先）

---

## 2. 対象ファイル構成

```
Vault (iCloud):
  ~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian_root/
    00.Daily/
      YYYY/
        YYYY-MM-DD.md    ← 対象ファイル

スクリプト格納先:
  ~/Dev/Obsidian_root/daily_frontmatter.sh

ログ:
  ~/Dev/Obsidian_root/.daily_frontmatter.log

launchd plist:
  ~/Library/LaunchAgents/com.toichiro.obsidian-daily-ai.plist
```

**既存ノート例（2025-12-29.md）**:
```markdown
---
date: 2025-12-29
summary: 夜中に呼び止められ、相手の心の葛藤や過去の話を聞き、冗談で済ませて許し合った。
tags: ["#ctx/家族", "#feel/安堵", "#lvl/4", "#対話", "#許し", "#関係修復", "#夫婦", "#PMS"]
---

- 10:03
  昨日、夜中トイレに行ったら呼び止められた。...
```

---

## 3. frontmatter仕様

### フィールド定義

| フィールド | 型 | 説明 | 例 |
|-----------|-----|------|-----|
| `date` | string (YYYY-MM-DD) | ノートの日付 | `2025-12-29` |
| `summary` | string | その日の1文要約（80文字以内） | `夜中に呼び止められ...` |
| `tags` | string[] | タグ配列（Obsidian形式） | `["#ctx/家族", ...]` |

### タグ命名規則（既存パターンより）

```
#ctx/<文脈>      : 誰と何に関するか  例: #ctx/家族, #ctx/仕事, #ctx/自己
#feel/<感情>     : 感情の種類         例: #feel/安堵, #feel/不安, #feel/喜び
#lvl/<1-5>       : 感情強度           例: #lvl/1 〜 #lvl/5
#<キーワード>    : その日のテーマ     例: #対話, #許し, #達成, #学習
```

### 既存値がある場合のスキップ仕様

| 状況 | 動作 |
|------|------|
| frontmatterなし | 全フィールドをAI生成して書き込む |
| frontmatterあり・全フィールド存在 | スキップ（何もしない） |
| frontmatterあり・一部フィールド欠損 | 欠損フィールドのみAI生成して補完 |

---

## 4. AIプロンプト設計

### 4.1 summary生成プロンプト

```
あなたは要約のプロです。今日のジャーナルセンテンスの内容を80文字以内で要約してください。

【デイリーノート本文】
{BODY_TEXT}
```

### 4.2 タグ生成プロンプト

```
あなたはObsidianのタグを生成するアシスタントです。

以下のデイリーノートの本文を読み、適切なタグを生成してください。

【タグ命名規則】
1. #ctx/<文脈>: 誰と・何に関するか（例: #ctx/家族, #ctx/仕事, #ctx/自己, #ctx/友人）
2. #feel/<感情>: 感情の種類（例: #feel/安堵, #feel/不安, #feel/喜び, #feel/疲れ, #feel/充実）
3. #lvl/<1-5>: 最も強い感情の強度（1=弱, 5=強）
4. #<テーマ>: その日のキーワード（2〜4個、例: #対話, #達成, #学習, #家族時間）

【出力形式】
JSON配列のみを出力してください（前後に説明不要）:
["#ctx/XXX", "#feel/XXX", "#lvl/X", "#テーマ1", "#テーマ2"]

【デイリーノート本文】
{BODY_TEXT}
```

---

## 5. Ollama設定

### モデル設定（設定ファイルで管理）

| 項目 | 値 |
|------|----|
| モデルID | 設定ファイルで管理（評価候補: `gemma3:12b`） |
| 実装 | ローカルOllama |
| 最大コンテキスト（公称） | 128K tokens（gemma3:12b使用時） |
| Ollamaデフォルトコンテキスト | 8,192 tokens（要注意） |
| 本スクリプトで使用するnum_ctx | **8,192**（デイリーノートは短いため十分） |

**設定変数（スクリプト冒頭で定義）**:

```bash
# モデル設定（設定ファイル ~/Dev/Obsidian_root/config.sh で上書き可能）
OLLAMA_MODEL="${OLLAMA_MODEL:-gemma3:12b}"
```

### コンテキスト長の試算

既存デイリーノート本文の平均長さ: **約200〜500文字**（≒150〜400トークン）

プロンプト長（固定部分）: 約300トークン

| 対象 | 推定入力トークン | num_ctx必要値 |
|------|----------------|--------------|
| summary生成 | 400〜700 tokens | 8,192（デフォルト）で十分 |
| タグ生成 | 400〜700 tokens | 8,192（デフォルト）で十分 |

**結論**: デイリーノートはデフォルト8Kコンテキストで処理可能。

### ローカル優先・フォールバック方式

```bash
# Ollama稼働確認
if ! curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
  log "ERROR: Ollama not running. Skip."
  exit 1
fi

# 使用モデル設定（設定ファイルで変更可能）
OLLAMA_MODEL="${OLLAMA_MODEL:-gemma3:12b}"

# Ollamaモデル確認
if ! ollama list | grep -q "$OLLAMA_MODEL"; then
  log "ERROR: $OLLAMA_MODEL not found. Run: ollama pull $OLLAMA_MODEL"
  exit 1
fi
```

フォールバック（v1では実装しない・将来拡張）:
- Ollama未起動 → ログ記録して終了（エラー通知は将来検討）

---

## 6. スクリプト仕様（daily_frontmatter.sh）

### ファイルパス

```bash
SCRIPT="$HOME/Dev/Obsidian_root/daily_frontmatter.sh"
VAULT="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian_root"
DAILY_DIR="$VAULT/00.Daily"
LOG="$HOME/Dev/Obsidian_root/.daily_frontmatter.log"
```

### 引数・オプション

```bash
# 通常実行（前日のノートを処理）
./daily_frontmatter.sh

# テスト用（日付指定）
./daily_frontmatter.sh 2025-12-29
./daily_frontmatter.sh --date 2025-12-29

# ドライラン（ファイル書き込み不実施・標準出力のみ）
./daily_frontmatter.sh --dry-run
./daily_frontmatter.sh --dry-run --date 2025-12-29
```

**処理対象の日付決定ロジック**:
```bash
if [ -n "$DATE_ARG" ]; then
  TARGET_DATE="$DATE_ARG"
else
  # 0:15実行なので「前日」のノートを対象とする
  TARGET_DATE=$(date -v-1d +%Y-%m-%d)  # macOS
fi
```

### dataviewjsブロック除外方法

Ollamaへ送る本文から、dataviewjsブロック（コードとして埋め込まれたJavaScript）を除外する:

```bash
# dataviewjsブロック除外（```dataviewjs ... ``` を削除）
BODY_TEXT=$(sed '/^```dataviewjs$/,/^```$/d' "$NOTE_FILE")

# また、frontmatterブロック（--- ... ---）も除外
BODY_TEXT=$(echo "$BODY_TEXT" | awk '/^---$/{f++; next} f==1{next} f>=2{print}')
```

### ログ出力仕様

```
[2026-02-28 00:15:01] START: processing 2026-02-27.md
[2026-02-28 00:15:01] SKIP: frontmatter already complete
[2026-02-28 00:15:01] START: processing 2026-02-27.md
[2026-02-28 00:15:03] Ollama summary generated: 夜中に呼び止められ...
[2026-02-28 00:15:05] Ollama tags generated: ["#ctx/家族", ...]
[2026-02-28 00:15:05] DONE: frontmatter written to 2026-02-27.md
[2026-02-28 00:15:05] ERROR: Ollama not running
```

ログローテーション: ファイルが1MB超えたら末尾500行のみ保持

### エラーハンドリング

| エラー状況 | 動作 |
|-----------|------|
| 対象ノートファイルが存在しない | ログ記録して終了（当日記録なしは正常） |
| Ollama未起動 | ERROR ログ → 終了（ファイル変更なし） |
| 使用モデル未pull（$OLLAMA_MODEL） | ERROR ログ → 終了 |
| Ollamaレスポンスが不正（JSON解析失敗） | ERROR ログ → frontmatter書き込み中断 |
| iCloudファイルロック（書き込み失敗） | リトライ3回 → 失敗時はERROR ログ |

---

## 7. launchd設定

### plist名

```
com.toichiro.obsidian-daily-ai.plist
```

### 設定内容

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.toichiro.obsidian-daily-ai</string>

  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>/Users/toichiro/Dev/Obsidian_root/daily_frontmatter.sh</string>
  </array>

  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key>
    <integer>0</integer>
    <key>Minute</key>
    <integer>15</integer>
  </dict>

  <key>StandardOutPath</key>
  <string>/Users/toichiro/Dev/Obsidian_root/.daily_frontmatter.log</string>

  <key>StandardErrorPath</key>
  <string>/Users/toichiro/Dev/Obsidian_root/.daily_frontmatter.log</string>

  <key>RunAtLoad</key>
  <false/>
</dict>
</plist>
```

### ログパス

```
~/Dev/Obsidian_root/.daily_frontmatter.log
```

### インストール手順（参考・実装時確認）

```bash
cp com.toichiro.obsidian-daily-ai.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.toichiro.obsidian-daily-ai.plist
launchctl list | grep obsidian-daily-ai  # 確認
```

---

## 8. テスト計画

### 単体テスト（スクリプト直接実行）

| テストケース | 条件 | 期待動作 |
|------------|------|---------|
| T1: frontmatterなし | 本文のみのノート | 全フィールド生成・書き込み |
| T2: frontmatterあり（全フィールド） | 完全なfrontmatter | スキップ（ファイル変更なし） |
| T3: frontmatterあり（summaryのみ欠損） | dateとtagsはある | summaryのみ生成・補完 |
| T4: dataviewjsブロックあり | dataviewjsを含む本文 | dataviewjsを除いた本文でAI処理 |
| T5: ノートファイルなし | 当日記録なし | ログ記録して正常終了 |
| T6: Ollama未起動 | ollamaサービス停止 | ERROR ログ → 正常終了 |
| T7: ドライラン | --dry-run オプション | 標準出力のみ・ファイル変更なし |

### 統合テスト（手動実行確認）

1. `./daily_frontmatter.sh --date 2025-12-28 --dry-run` でドライラン確認
2. `./daily_frontmatter.sh --date 2025-12-28` で実際に書き込み
3. 生成されたfrontmatterをObsidianで表示確認

### launchdテスト

```bash
# 手動トリガー
launchctl start com.toichiro.obsidian-daily-ai
# ログ確認
tail -20 ~/Dev/Obsidian_root/.daily_frontmatter.log
```
