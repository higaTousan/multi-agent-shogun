# cmd_265 設計書: Obsidian Journal Insight Navigator 自動化（週次・月次・年次）

**version**: 1.0
**作成日**: 2026-02-28
**作成者**: 軍師
**ステータス**: 殿レビュー待ち（モデル選定の最終判断必要）

---

## 1. 概要・目的

GEMINI.md の「Journal Insight Navigator」プロンプトに基づき、
Obsidianデイリーノートの週次・月次・年次分析レポートをlaunchdジョブで自動生成する。

**解決したい課題**:
- 毎週・毎月のレポート作成がGeminiとの対話で手作業になっており、時間がかかる
- 分析の質・フォーマットを一定に保つのが難しい

**アプローチ**:
- GEMINI.mdのJournal Insight Navigatorプロンプトをシェルスクリプト内に内包し、AI APIに送信
- 生成されたレポートをVaultの所定パスに自動保存し、スコアチャートも差分更新

---

## 2. 対象ファイル構成

```
Vault (iCloud):
  ~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian_root/
    00.Daily/
      YYYY/
        YYYY-MM-DD.md               ← 入力: デイリーノート
    10.Meta/
      Analysis/
        Weekly/
          Analysis_YYYY-MM-DD_YYYY-MM-DD.md   ← 出力: 週次レポート
        Monthly/
          Monthly_YYYYMM.md                   ← 出力: 月次レポート（※既存確認必要）
        Yearly/
          Yearly_YYYY.md                      ← 出力: 年次レポート
        Charts/
          Weekly_Scores.md                    ← 差分更新: 週次スコアチャート
          Monthly_Scores.md                   ← 差分更新: 月次スコアチャート
          Yearly_Scores.md                    ← 差分更新: 年次スコアチャート
    Profile.md                    ← 分析前読み込み（GEMINI.md原則0参照）

スクリプト格納先:
  ~/Dev/Obsidian_root/
    weekly_analysis.sh
    monthly_analysis.sh
    yearly_analysis.sh

ログ:
  ~/Dev/Obsidian_root/.periodic_analysis.log
```

### 月次レポートの実際のパス（要確認）

> ⚠️ 現在のVaultで月次レポートのディレクトリが `10.Meta/Analysis/Monthly/` か
> 別のパスかを確認すること。`Analysis/` 直下に `Metanalysis_YYYY-MM-DD_YYYY-MM-DD.md` として
> 週次レポートのみ存在する可能性がある。実装時にGlobで確認すること。

---

## 3. GEMINI.mdルール準拠

### 3.1 事実ベース・推測禁止・根拠明示ルールの自動化方針

GEMINI.md「応答生成に関する厳格な原則」より:
- 原則1: 情報源を `00.Daily/` と `10.Meta/Analysis/` に限定
- 原則2: 実際に取得した情報のみを根拠とする
- 原則3: ファイル内容を推測しない
- 原則6: 各分析項目に根拠引用を明示

**自動化での対応**:
- スクリプトが対象ファイルを読み込んでからプロンプトに埋め込む（推測不可能な構造）
- プロンプトに「根拠を必ず引用すること」を明示する
- 出力にwikilink形式の根拠引用を含めるよう指示する

### 3.2 スコア算定基準（GEMINI.md準拠）

以下のスコアを各レポートに含める:

```
行動効率スコア（1〜10）: ToDoリストの消化率・計画達成度
感情安定度スコア（1〜10）: 感情の波の小ささ
成長指数（1〜10）: 自己調整力（0〜6）＋能力拡張（0〜4）
感情マネジメントスコア（1〜10）: ラベリング/リフレーミング/アファメーション/スカーシティ総合
```

月次スコアは「週次スコア平均」ベース（補正±1まで、根拠必須）。

### 3.3 セクション構成（GEMINI.md週次レポートテンプレート準拠）

```markdown
### 長期分析（YYYY/MM/DD - YYYY/MM/DD）
#### 1. 長期要約
#### 2. 認知フィルター分析結果（ETF抽出）
   必須追記（認知フィルター詳細）
#### 3. 感情の傾向
#### 4. 思考の変化
#### 5. 感情マネジメントの傾向
### スコア評価
### 長期メタ認知コメント（第三者視点）
### 長期改善提案
（週次のみ: 前回分析との照合）
### 総評（必須）
```

月次レポートには加えて `1b. 週別サマリ` と `1c. 週次スコアチャート` が必要。

---

## 4. AIモデル選定

### 4.1 gemma3:12b（ローカルOllama）の入力トークン限界試算

**前提情報**:
- gemma3:12b 公称コンテキスト: **128K tokens**
- Ollama デフォルト num_ctx: **8,192 tokens**（要明示的設定）
- 週次レポート例（Analysis_2026-01-19_2026-01-25.md）: 約2,500文字 ≈ 2,000 tokens
- デイリーノート平均（実測）: 約200〜500文字 ≈ 150〜400 tokens
- GEMINI.mdプロンプト全体: 約6,000文字 ≈ 4,800 tokens

**入力量見積もり（プロンプト+入力データ合計）**:

| 分析種別 | 入力データ | 推定トークン（データ） | プロンプト含む合計 | 必要num_ctx |
|----------|-----------|---------------------|-----------------|------------|
| 週次（7日分） | デイリー7件 × 350 tokens | 2,450 tokens | ~7,250 tokens | **8,192**（ギリギリ・要確認） |
| 月次（4〜5週分） | 週次レポ4-5件 × 2,000 tokens | 8,000〜10,000 tokens | ~13,000〜15,000 tokens | **16,384** |
| 年次（12月分） | 月次レポ12件 × 5,000 tokens | 60,000 tokens | ~65,000 tokens | **65,536** |

> ⚠️ 週次分析はプロンプト+データが8Kを超える可能性あり。`num_ctx=16384` が安全。

### 4.2 Ollama処理困難な場合の代替案評価

**週次・月次**: gemma3:12b (Ollama) で対応可能（num_ctx適切設定で）

**年次**: 月次12件の合計が65K+ tokens → gemma3:12bでも理論上は128K範囲内だが、
実際のパフォーマンスは要検証。代替案を以下に評価:

| 選択肢 | コンテキスト | コスト | 品質 | 評価 |
|--------|------------|--------|------|------|
| gemma3:12b（Ollama）| 128K (要設定) | 無料 | ローカルLLM品質 | ◯ 年次も一応可能 |
| **gemini-2.5-flash**（Gemini API） | **1M tokens** | 無料枠あり | 高品質 | ◎ **推奨** |
| gemini-2.0-flash | 1M tokens | 無料枠あり | 高品質 | △ 2026年6月退役予定 |
| gemini-2.5-pro | 1M tokens | 有料 | 最高品質 | △ コスト要検討 |

**軍師推奨モデル選定方針**:
- 週次: gemma3:12b（Ollama）`num_ctx=16384`
- 月次: gemma3:12b（Ollama）`num_ctx=32768`
- 年次: **Gemini API（gemini-2.5-flash）** ← コスト0・1M context・品質高

ただし、**最終判断は殿への確認事項**（セクション8参照）。

**参考: Gemini API最新モデルID（2026-02-28調査）**:
- `gemini-2.5-flash` — 1M context、無料枠あり（現行推奨）
- `gemini-2.5-pro` — 1M context、有料
- `gemini-2.0-flash` — 1M context、2026年6月退役予定
- ※ WebSearch調査済み（情報鮮度ルール準拠）

---

## 5. スクリプト設計方針

### 5.1 3スクリプト構成案 vs 共通スクリプト案の評価

| 案 | 内容 | メリット | デメリット |
|----|------|---------|-----------|
| **案A: 3スクリプト構成** | weekly_analysis.sh / monthly_analysis.sh / yearly_analysis.sh | 各スクリプトが独立・テストしやすい | コード重複あり |
| 案B: 共通スクリプト | periodic_analysis.sh --type weekly/monthly/yearly | コード一元管理 | 引数処理が複雑 |

**推奨: 案A（3スクリプト構成）**

理由:
- 各分析種別で入力データ収集ロジックが異なる（週次=デイリー7件、月次=週次レポート4-5件、年次=月次レポート12件）
- launchdジョブも3つ別々に設定するため、スクリプトも分離した方が管理しやすい
- 将来的なモデル変更（週次はOllama、年次はGemini等）に対応しやすい

### 5.2 各スクリプトの処理フロー

#### weekly_analysis.sh

```
1. 先週の日付範囲を計算（月曜〜日曜）
2. 00.Daily/YYYY/YYYY-MM-DD.md を7件収集（存在するファイルのみ）
3. 既存の同期間レポートが存在する場合はスキップ
4. Profile.md を読み込む（GEMINI.md原則0: メタ情報の事前読み込み）
5. 直近週次レポートを読み込む（前回分析との照合用）
6. GEMINI.md「長期分析」プロンプト + 収集データ を構築
7. Ollama (gemma3:12b, num_ctx=16384) へ送信
8. 生成結果を 10.Meta/Analysis/Weekly/Analysis_YYYY-MM-DD_YYYY-MM-DD.md に保存
9. Weekly_Scores.md を差分更新
10. ログ記録
```

#### monthly_analysis.sh

```
1. 先月の月を計算
2. 10.Meta/Analysis/Weekly/ から先月分の週次レポートを収集（Glob）
3. 既存の同月レポートが存在する場合はスキップ
4. Profile.md を読み込む
5. GEMINI.md「月次レポートテンプレート」プロンプト + 週次レポート を構築
6. Ollama (gemma3:12b, num_ctx=32768) へ送信
7. 生成結果を 10.Meta/Analysis/Monthly/Monthly_YYYYMM.md に保存
8. Monthly_Scores.md を差分更新
9. ログ記録
```

#### yearly_analysis.sh

```
1. 前年の年を計算
2. 10.Meta/Analysis/Monthly/ から前年分の月次レポートを収集（Glob）
3. 既存の同年レポートが存在する場合はスキップ
4. Profile.md を読み込む
5. GEMINI.md「長期分析」プロンプト + 月次レポート を構築
6. Gemini API (gemini-2.5-flash) へ送信
7. 生成結果を 10.Meta/Analysis/Yearly/Yearly_YYYY.md に保存
8. Yearly_Scores.md を差分更新
9. ログ記録
```

### 5.3 前回レポートとの照合（セクション8）の実装方法

GEMINI.md「8. 前回分析との照合（必須）」をプロンプトに含める:

```bash
# 直近の週次レポートを取得
PREV_REPORT=$(ls -t "$VAULT/10.Meta/Analysis/Weekly/Analysis_*.md" 2>/dev/null | head -1)

if [ -n "$PREV_REPORT" ]; then
  PREV_CONTENT=$(cat "$PREV_REPORT")
  # プロンプトに前回レポートを追加
  PROMPT="$PROMPT\n\n【前回分析レポート（照合用）】\n$PREV_CONTENT"
fi
```

### 5.4 iCloud Vault直接編集の注意点

| リスク | 対策 |
|--------|------|
| iCloud同期中のファイルロック | 書き込み前に `xattr` でiCloudステータス確認 |
| 書き込み中のObsidian編集競合 | tmpファイルに書き込んでからmv（アトミック操作） |
| ファイルエンコーディング | UTF-8 BOMなしで出力（Obsidian標準） |

```bash
# アトミックな書き込み
TMP_FILE=$(mktemp)
echo "$REPORT_CONTENT" > "$TMP_FILE"
mv "$TMP_FILE" "$OUTPUT_FILE"
```

---

## 6. launchd設定

### 3ジョブの設定一覧

| ジョブ | plist名 | 実行タイミング | スクリプト |
|--------|---------|--------------|-----------|
| 週次 | `com.toichiro.obsidian-weekly-analysis.plist` | **毎週月曜 0:30** | `weekly_analysis.sh` |
| 月次 | `com.toichiro.obsidian-monthly-analysis.plist` | **毎月1日 1:00** | `monthly_analysis.sh` |
| 年次 | `com.toichiro.obsidian-yearly-analysis.plist` | **1月1日 2:00** | `yearly_analysis.sh` |

### cmd_264（0:15）との依存関係

- 週次（月曜0:30）: cmd_264（0:15）の後に実行。先週日曜のデイリーノートfrontmatterが0:15に生成された後、週次分析が0:30に実行される。
- **順序独立**: 週次分析はデイリーノートの本文を直接読むため、cmd_264のfrontmatter生成と論理的な依存関係はない。ただし実行順序（0:15 → 0:30）は維持する。

### 週次ジョブ plist例

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.toichiro.obsidian-weekly-analysis</string>

  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>/Users/toichiro/Dev/Obsidian_root/weekly_analysis.sh</string>
  </array>

  <key>StartCalendarInterval</key>
  <dict>
    <key>Weekday</key>
    <integer>1</integer>
    <key>Hour</key>
    <integer>0</integer>
    <key>Minute</key>
    <integer>30</integer>
  </dict>

  <key>StandardOutPath</key>
  <string>/Users/toichiro/Dev/Obsidian_root/.periodic_analysis.log</string>

  <key>StandardErrorPath</key>
  <string>/Users/toichiro/Dev/Obsidian_root/.periodic_analysis.log</string>

  <key>RunAtLoad</key>
  <false/>
</dict>
</plist>
```

---

## 7. テスト計画

### 週次レポートの手動実行テスト計画

```bash
# STEP 1: 過去日付を指定したドライラン（2026-01-19週を対象）
./weekly_analysis.sh --week 2026-01-19 --dry-run

# STEP 2: 既存レポートと比較（品質確認）
# 期待: Analysis_2026-01-19_2026-01-25.md の既存内容と類似した構造
./weekly_analysis.sh --week 2026-01-19

# STEP 3: 生成ファイル確認
ls -la ~/Library/Mobile\ Documents/iCloud~md~obsidian/Documents/Obsidian_root/10.Meta/Analysis/Weekly/

# STEP 4: Weekly_Scores.md の差分更新確認
cat ~/Library/Mobile\ Documents/.../Charts/Weekly_Scores.md
```

### テストチェックリスト

| 確認項目 | 期待値 |
|---------|-------|
| GEMINI.mdのセクション構成が出力に存在 | 全8セクション（長期要約〜総評）あり |
| スコア4項目がすべて含まれる | 行動効率・感情安定度・成長指数・感情マネジメント |
| 根拠引用が存在 | 各セクションに `根拠: [[00.Daily/...]]` あり |
| Weekly_Scores.md が更新される | 新しい週のデータが追記されている |
| 既存レポートが上書きされない | スキップ判定が正常動作 |
| ドライランでファイル変更なし | 標準出力のみ |

---

## 8. 残課題・殿への確認事項

### 🚨 A. モデル選定の最終判断（最重要）

| 分析種別 | 軍師推奨 | 代替案 |
|----------|---------|--------|
| 週次 | gemma3:12b（Ollama, num_ctx=16384） | gemini-2.5-flash |
| 月次 | gemma3:12b（Ollama, num_ctx=32768） | gemini-2.5-flash |
| 年次 | **gemini-2.5-flash（Gemini API）** | gemma3:12b（128K設定）|

**確認事項**: 年次分析にGemini APIを使用してよいか？
Gemini APIは現状 gemini-2.5-flash が無料枠あり（2026-02-28時点）。
ただし無料枠の制限・キーの設定が必要。

**統一案（全分析をGemini APIに）**: 品質一貫性とセットアップ簡素化のため、
週次・月次・年次すべてをGemini API（gemini-2.5-flash）にする選択肢もある。
Ollamaの設定複雑さを避けられる。

### B. 月次レポートの既存パスの確認

現在のVaultで月次レポートが存在するか、どのパスに保存されているかを確認すること。
`10.Meta/Analysis/Monthly/` が存在しない場合は新規作成。

### C. GEMINI.mdに記載されていない設計判断事項

以下はGEMINI.mdに明示されていないため、設計上の判断が必要:

1. **分析対象週の日付範囲**: 月曜始まり（ISO週）か日曜始まりか？
   → 軍師案: 月曜〜日曜（現在の週次レポートファイル名より）

2. **デイリーノートが存在しない日の扱い**: 旅行中など記録がない日がある場合
   → 軍師案: 存在するファイルのみ収集し、プロンプトに「N日分のデータ」と明記

3. **生成レポートの命名規則の厳密化**:
   - 週次: `Analysis_YYYY-MM-DD_YYYY-MM-DD.md`（現行と同じ）
   - 月次: `Monthly_YYYYMM.md` か `Metanalysis_YYYY-MM-DD_YYYY-MM-DD.md` か？
   → 現行の月次レポートが存在しないため確認が必要

4. **スクリプトの実行中ログのObsidian表示**: `.periodic_analysis.log` は
   Vaultの外（`~/Dev/Obsidian_root/`）に置くため、Obsidianには表示されない。
   これでよいか？

5. **Gemini API キーの管理**: `~/.config/` 等に環境変数として設定するか、
   launchdの `EnvironmentVariables` キーで設定するか？
   → セキュリティ上、ファイルパーミッション管理が必要。
