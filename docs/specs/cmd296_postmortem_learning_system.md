# cmd_296 設計書: ポストモーテム学習システム（自律的失敗学習基盤）

**version**: 1.0
**作成日**: 2026-03-03
**作成者**: 軍師
**ステータス**: 殿レビュー待ち

---

## 1. 概要・WHY

### 解決する本質問題

現状のマルチエージェント体制では、失敗が繰り返される構造的欠陥がある。

```
失敗発生 → 教訓をMemory MCP/CLAUDE.mdに記録 → /clear・コンパクションで消える → 同じ失敗を繰り返す
```

**根本問題**: 教訓をエージェントの記憶に依存している。エージェントは状態を持たない。

直近実例（cmd_295で特定）:
1. Python `X | None` 型構文 → launchd Python 3.9で失敗（実行環境バージョン確認漏れ）
2. zettelkastenスクリプトがOllama参照のまま残存（スコープ定義の穴）
3. launchdジョブをexit_code=0のみで検証し、ログ内容を確認しなかった（QC確認手順の不備）

### 必要な設計思想

> **「エージェントが覚えておく」前提を捨て、「仕組みが強制する」設計に移行する**

- **永続化**: ファイルベース。/clear後・コンパクション後も消えない
- **自動注入**: QC実行時に過去失敗観点が自動的に提供される
- **低摩擦**: 既存ワークフローへの影響を最小化
- **コンテキスト効率**: サマリー活用でコンテキストウィンドウを圧迫しない

---

## 2. システム全体像（フロー図）

```
【失敗発生時のフロー】
足軽 status:failed 報告
  または 家老が品質問題検知
    ↓
/postmortem Skill 実行（家老 or 足軽）
    ↓
queue/postmortems/YYYYMMDD_cmdXXX_subtaskXXX.yaml 生成
    ↓
scripts/update_active_patterns.sh 自動実行
    ↓
queue/postmortems/ACTIVE_PATTERNS.md 更新（常時最新）

【QC実行時のフロー】
家老が QC タスク YAML 作成
    ↓
軍師がQC開始 → ACTIVE_PATTERNS.md を必ず読み込む（ワークフロー固定ステップ）
    ↓
過去失敗パターンを照合しながらQC実施
    ↓
軍師 QC レポートに「照合した失敗パターン」を記載

【定期サマリー生成フロー（月次）】
毎月1日 launchd または 家老の手動トリガー
    ↓
scripts/generate_postmortem_summary.sh
    ↓
queue/postmortems/summaries/YYYY-MM_summary.md 生成
    ↓
ACTIVE_PATTERNS.md を最新状態に刷新
```

---

## 3. /postmortem Skill 仕様

### 3.1 概要

失敗事象を構造化YAMLとして記録するSkillコマンド。

- **ファイル**: `~/.claude/skills/postmortem/SKILL.md`
- **呼び出し**: `/postmortem` または「ポストモーテム記録して」「失敗を記録」
- **実行者**: 家老（主）または足軽（自分の失敗を記録する場合）

### 3.2 トリガー条件

| 条件 | 実行者 | タイミング |
|------|--------|----------|
| 足軽の `status: failed` 報告受信時 | 家老 | 即時（QC前でも可） |
| QCで重大な設計・実装問題を検出時 | 軍師 | QCレポート作成後 |
| 同一問題の2回目発生検知時 | 家老 | 即時（再発防止最優先） |
| 殿の直命「ポストモーテムを記録せよ」 | 将軍/家老 | 即時 |

### 3.3 失敗カテゴリ定義

| カテゴリID | 名称 | 説明 | 実例 |
|-----------|------|------|------|
| `env_mismatch` | 環境差異 | OS・Pythonバージョン・ツールバージョンの違い | Python 3.9でtype union構文失敗 |
| `scope_omission` | スコープ漏れ | 影響範囲の見落とし・変更漏れ | zettelkastenがOllama参照のまま |
| `verification_gap` | 確認手順不備 | テスト・QC・ログ確認の不足 | exit_code=0のみでログ未確認 |
| `design_flaw` | 設計不備 | アーキテクチャ・インターフェース問題 | プロバイダー固有名の命名（OLLAMA_MODEL等） |
| `implementation_error` | 実装ミス | コードバグ・ロジックエラー | 境界値・型変換ミス |
| `info_accuracy` | 情報精度 | 古い情報・未確認情報の使用 | 旧モデルIDで「利用不可」と判断 |
| `comm_gap` | 伝達ミス | WHY消失・指示誤解・仕様伝達不備 | 「品質比較」→「ファイル生成」に変質 |
| `other` | その他 | 上記に当てはまらない失敗 | — |

### 3.4 /postmortem Skill の動作仕様

```
STEP 1: 対象 cmd_id / subtask_id をユーザーに確認（または引数から取得）

STEP 2: 失敗カテゴリ選択を促す（上記8カテゴリから選択）

STEP 3: 構造化情報を収集（以下の質問を順に提示）:
  1. 何が起きたか（事象の説明）
  2. なぜ検知できなかったか（QC・テストの欠陥）
  3. 根本原因（WHY×3以上を促す）
  4. 同じ失敗を防ぐための仕組み改善案

STEP 4: YAML生成・保存
  出力先: queue/postmortems/YYYYMMDD_cmdXXX[_subtaskXXX].yaml

STEP 5: ACTIVE_PATTERNS.md を更新
  scripts/update_active_patterns.sh を実行
```

### 3.5 ポストモーテムYAMLスキーマ

```yaml
# queue/postmortems/20260303_cmd295_subtask295a.yaml
postmortem:
  id: "PM-2026-003"                         # 自動採番: PM-YYYY-NNN
  timestamp: "2026-03-03T13:00:00"
  cmd_id: "cmd_295"
  subtask_id: "subtask_295a"               # オプション（cmd全体の場合は省略）
  recorded_by: "gunshi"                     # 記録者エージェント
  severity: "medium"                        # low | medium | high | critical
  category: "verification_gap"              # 3.3のカテゴリIDから選択
  tags: ["python", "launchd", "log_check"] # 検索用タグ（3つ以内推奨）
  status: "active"                          # active | resolved | superseded
  resolved_by: ""                           # 解決したcmd_idを記載（解決後）

  title: "launchdジョブのexit_code=0のみでログ内容を未確認"

  what_happened: |
    launchdジョブがexit_code=0で完了するが、実際にはPython 3.9の
    type union構文エラーが発生。ログ確認を省略したため検知できなかった。

  why_not_detected: |
    QCチェックリストにログ内容確認項目がなく、exit_code=0を
    成功の証拠と誤認した。

  root_causes:
    - why1: "QCでexit_code=0のみを確認基準とした"
    - why2: "QCチェックリストにログ確認項目がなかった"
    - why3: "スクリプト作成時に実行環境のPythonバージョンを確認しなかった"

  systemic_improvements:
    - "軍師QCチェックリストに「ログ内容確認」を必須項目として追加"
    - "シェルスクリプト内でPythonバージョン確認を必須化（python3 --version）"

  lessons:
    - "exit_code=0は「プロセスが死ななかった」を意味するだけ。ログで実際の動作を確認せよ"
    - "実行環境のPythonバージョンを前提確認してから型構文を選べ"
```

---

## 4. レポート蓄積設計

### 4.1 ディレクトリ構造

```
queue/
  postmortems/
    20260303_cmd295_subtask295a.yaml     ← 個別ポストモーテム（YYYYMMDD_cmdXXX[_subtaskXXX].yaml）
    20260303_cmd296.yaml
    ACTIVE_PATTERNS.md                   ← 常時最新の有効パターン集（軍師QCが読む）
    summaries/
      2026-02_summary.md                 ← 月次サマリー
      2026-03_summary.md
```

### 4.2 既存ファイルとの関係

| 既存ファイル | 新設計との関係 |
|------------|----------------|
| `queue/reports/postmortem_cmd211_model_id.md` | 既存ファイルはそのまま保持。新規記録は `queue/postmortems/` に追加。移行は任意（コスト不要） |
| `queue/reports/postmortem_*.md` | 同上。古いポストモーテムをYAML変換するスクリプトを用意するが、移行は義務としない |

### 4.3 命名規則

```
queue/postmortems/{YYYYMMDD}_{cmd_id}[_{subtask_id}].yaml

例:
  20260303_cmd295.yaml               ← cmd全体のポストモーテム
  20260303_cmd295_subtask295a.yaml  ← サブタスク単位
  20260219_cmd211.yaml               ← cmd_211のポストモーテム（既存を移行する場合）
```

### 4.4 重大度基準

| 重大度 | 基準 | 対応 |
|--------|------|------|
| `critical` | 本番データ損失・セキュリティインシデント・全エージェント停止 | 即時対応・殿への直報必須 |
| `high` | 誤ったアーキテクチャ決定・コスト2倍超過・殿が自ら発見した問題 | 当日中に対応方針を策定 |
| `medium` | QC見逃し・スコープ漏れ・テスト不足 | 次cmdで改善策を実施 |
| `low` | 軽微なミス・自ら検知して修正済み | 記録のみ（改善策は任意） |

---

## 5. 定期サマリー生成設計

### 5.1 生成トリガー

| トリガー | タイミング | 実行者 |
|---------|-----------|--------|
| 月次自動 | 毎月1日 09:00（launchd） | `scripts/generate_postmortem_summary.sh` |
| 件数閾値 | 新規ポストモーテム5件蓄積時 | `update_active_patterns.sh` 内で自動チェック |
| 手動 | 家老が必要と判断した時 | 家老が `/postmortem summary` を実行 |

### 5.2 月次サマリー形式

```markdown
# ポストモーテムサマリー: 2026年3月

**集計期間**: 2026-03-01 〜 2026-03-31
**総件数**: 5件（high: 1, medium: 3, low: 1）

## カテゴリ別集計

| カテゴリ | 件数 | 割合 |
|---------|------|------|
| verification_gap | 2 | 40% |
| scope_omission | 1 | 20% |
| env_mismatch | 1 | 20% |
| info_accuracy | 1 | 20% |

## 頻出タグ Top5

python(3), launchd(2), qc_check(2), scope(1), model_id(1)

## 再発パターン（複数cmdで発生）

### 【再発: verification_gap】exit_code確認のみでログ未確認
- 発生: cmd_295（2回目）、cmd_289（1回目）
- 対策: QCチェックリストにlog_content_check項目追加（未実施）

## 今月の構造改善（実施済み）

- QCワークフローに ACTIVE_PATTERNS.md 読み込みステップを追加（cmd_296）

## 来月の改善候補

- [ ] Pythonスクリプト実行前のバージョン確認を自動化
```

### 5.3 ACTIVE_PATTERNS.md 形式

軍師がQC時に読む「有効な失敗パターンチェックリスト」。100行以内を維持。

```markdown
# ACTIVE_PATTERNS.md — QC照合チェックリスト

**最終更新**: 2026-03-03T13:00:00
**有効パターン件数**: 8件

## ⚠️ 高優先度パターン（high/critical）

### [env_mismatch] 実行環境のPythonバージョン確認
- **関連cmd**: cmd_295
- **確認観点**: Pythonスクリプトを使う場合、`python3 --version` で実行環境バージョンを確認したか？
- **NGパターン**: `X | None` 型構文をPython 3.9以下の環境で使用

### [info_accuracy] 外部APIモデルIDの複数バージョン確認
- **関連cmd**: cmd_211
- **確認観点**: 外部APIのモデルIDを1つだけ調べて「利用不可」としていないか？
- **NGパターン**: `deepseek-v3-0324` → 「利用不可」（実際は `deepseek/deepseek-v3.2` が利用可）

## ⚡ 中優先度パターン（medium）

### [verification_gap] launchdジョブのログ確認
- **関連cmd**: cmd_295
- **確認観点**: exit_code=0のみでなく、ログファイルの内容も確認したか？
- **チェック**: `tail -n 50 {ログファイル}` で実際の出力を確認

### [scope_omission] モデル移行時の影響範囲確認
- **関連cmd**: cmd_295（zettelkasten Ollama参照残り）
- **確認観点**: モデル/ツール切替時に全スクリプト・設定ファイルを横断して参照箇所を確認したか？
- **チェック**: `grep -r "ollama\|OLLAMA" . --include="*.sh" --include="*.py"`

### [comm_gap] WHYが伝わっているか確認
- **関連cmd**: cmd_268, cmd_274
- **確認観点**: 足軽タスクYAMLにparent_cmdのWHY（目的）が記載されているか？
- **NGパターン**: acceptance_criteriaに「ファイルが存在すること」のみ記載し、目的達成条件がない
```

---

## 6. 軍師QC自動注入設計（最重要）

### 6.1 設計方針

**採用方針: ワークフロー固定読み込み（最小摩擦・最大信頼性）**

軍師QCワークフローに、ACTIVE_PATTERNS.md の読み込みを固定ステップとして組み込む。
「注入する仕組み」ではなく「軍師が必ず読む仕組み」として実装する。

| 方針候補 | 利点 | 欠点 |
|---------|------|------|
| A: QC YAML に `postmortem_context` フィールドを家老が毎回追加 | Karo主導で管理できる | 家老が忘れると機能しない |
| **B: 軍師QCワークフローの固定ステップ（採用）** | **自動・忘れない・家老の手間不要** | 軍師の instructions.md 変更が必要 |
| C: /postmortem-check Skill として呼び出し | 明示的で理解しやすい | 軍師が意図的に呼ばないと機能しない |

**方針Bを採用する理由**: /clear・コンパクション後も instructions.md は再読される（Session Start手順で必須）。
ワークフローステップとして組み込めば、エージェント交代後も必ず実行される。

### 6.2 instructions/gunshi.md への追加ステップ

```yaml
# 既存 workflow に追加するステップ（step 2.5 として挿入）
- step: 2.5
  action: read_active_patterns
  command: "Read queue/postmortems/ACTIVE_PATTERNS.md"
  condition: "type == quality_check"
  note: "QCタスクの場合のみ。ファイル未存在の場合はスキップ（初回のみ）"
```

### 6.3 QCレポートへの照合記録

軍師QCレポートに `postmortem_patterns_checked` フィールドを追加:

```yaml
result:
  type: quality_check
  postmortem_patterns_checked:
    - pattern: "exit_code=0のみでログ未確認"
      checked: true
      finding: "ログ確認済み（cat .analysis.log 出力を確認）"
    - pattern: "モデルID複数バージョン確認"
      checked: true
      finding: "今回のタスクはAPI調査なし。対象外。"
```

### 6.4 コンテキスト最適化

ACTIVE_PATTERNS.md は **100行以内** を維持する。
- resolved（解決済み）パターンは summaries/ に移動
- 類似パターンは統合
- 6ヶ月以上再発なしのパターンは `status: dormant` として末尾に移動
- `dormant` パターンはACTIVE_PATTERNS.md に含めない（代わりに summaries/ で参照可能）

---

## 7. 既存 design-review Skill との統合方針

### 7.1 関心の分離

| Skill | 対象 | タイミング | 観点 |
|-------|------|----------|------|
| `/design-review` | **Spec設計書** | Spec作成後・殿承認前 | 抽象度・拡張性・外部化の5軸 |
| `ACTIVE_PATTERNS.md読み込み` | **実装QC** | QC実行時（固定） | 過去の失敗パターン照合 |

### 7.2 推奨方針: 別ステップとして共存（統合しない）

**理由**:
1. design-review は設計フェーズ（Spec）の品質チェック。ACTIVE_PATTERNS照合は実装フェーズのQC。タイミングが異なる。
2. design-review の5軸は「良い設計の原則」。ACTIVE_PATTERNS照合は「軍固有の失敗履歴」。性質が異なる。
3. 統合すると design-review の適用場面（Spec QC）でも失敗履歴を読む無駄が生じる。

**関係図**:
```
Spec作成
  ↓
/design-review（5軸チェック）← 設計の普遍的品質基準
  ↓
殿承認
  ↓
実装（足軽）
  ↓
足軽 status:done 報告 → 軍師QC
                            ↓
                     ACTIVE_PATTERNS.md 読み込み ← 軍固有の失敗履歴
                            ↓
                     QCレポート（照合記録付き）
```

### 7.3 将来的な拡張（検討事項）

- `/design-review` に6軸目「過去失敗パターンとの整合」を追加することは可能
- ただし現時点では不要（Specフェーズで失敗履歴を照合する必要性は低い）
- 再発防止策がSpec設計に影響する場合（e.g., 設計不備パターンが蓄積された場合）に再検討

---

## 8. 実装フェーズ計画

> 本Specは設計書のみ。実装は殿の承認後、次cmdで着手。

### Phase 1: 基盤整備（最優先・依存なし）

| 作業 | 担当 | 成果物 |
|------|------|--------|
| `queue/postmortems/` ディレクトリ作成 | 足軽 | ディレクトリ + .gitkeep |
| `ACTIVE_PATTERNS.md` 初期版作成 | 軍師 | 既存postmortem_*.mdから既知パターンを構造化 |
| `scripts/update_active_patterns.sh` 実装 | 足軽 | 新規YAML追加時にACTIVE_PATTERNS.mdを更新するスクリプト |

### Phase 2: /postmortem Skill 実装

| 作業 | 担当 | 成果物 |
|------|------|--------|
| `~/.claude/skills/postmortem/SKILL.md` 作成 | 軍師 | Skill定義ファイル |
| Skill の動作テスト（手動） | 家老 | 動作確認レポート |

### Phase 3: 軍師QCワークフロー更新

| 作業 | 担当 | 成果物 |
|------|------|--------|
| `instructions/gunshi.md` にstep 2.5追加 | 家老 | 更新済みinstructions |
| QCレポートYAMLスキーマに `postmortem_patterns_checked` 追加 | 家老 | 更新済みinstructions |

### Phase 4: 定期サマリー自動化（後回し可）

| 作業 | 担当 | 成果物 |
|------|------|--------|
| `scripts/generate_postmortem_summary.sh` 実装 | 足軽 | サマリー生成スクリプト |
| launchd plist 作成（月次実行） | 足軽 | .plist ファイル |

### 依存関係

```
Phase 1 → Phase 2（ACTIVE_PATTERNS.mdが存在してからSkillが意味を持つ）
Phase 1 → Phase 3（ACTIVEが存在してからQCワークフローが機能する）
Phase 4 は独立（他Phaseと並行可能）
```

---

## 9. 殿への確認事項

| # | 確認事項 | 背景 |
|---|---------|------|
| 1 | `queue/postmortems/` をgit管理対象とするか？ | ポストモーテムが蓄積されていくため、履歴として残した方が価値がある。ただし機密情報（コスト・設計ミス）が含まれるため、.gitignoreに含める選択肢もあり。 |
| 2 | /postmortem Skill を足軽も呼び出せるようにするか？ | 現設計では家老/軍師が主体。足軽が自ら失敗を記録できる方が迅速だが、品質管理は家老に集中させる方が整合性が高い。 |
| 3 | 既存の `queue/reports/postmortem_*.md` を新スキーマに移行するか？ | 移行コスト約3件分。YAMLの恩恵（タグ検索・カテゴリ集計）を受けるには移行が望ましいが、マークダウンのままACTIVE_PATTERNS.mdに手動で取り込むことも可能。 |
| 4 | ACTIVE_PATTERNS.md の100行制限は適切か？ | 現時点では既知パターンは8〜10件程度。ただし1年後には20〜30件になりえる。50行・100行・制限なし、どれが望ましいか。 |
| 5 | Phase 4（月次自動化）の優先度 | Phase 1〜3で手動運用から始めることも可能。初期は「ポストモーテムを記録する習慣をつける」ことが先決。自動化は後でも間に合うか。 |

---

## 付録: design-review 結果

```
## design-review 結果: cmd296_postmortem_learning_system.md (v1.0)

| 軸 | 観点 | 判定 | 根拠・コメント |
|----|------|------|----------------|
| 1 | 命名の抽象度 | ✅ PASS | postmortem, active_patterns, summaryはツール非依存名。特定LLMやDBに依存しない |
| 2 | 差し替え耐性 | ✅ PASS | YAMLスキーマ変更はスキーマファイルのみ修正。スクリプトはファイルパスのみに依存 |
| 3 | 設定の外部化 | ⚠️ WARN | ACTIVE_PATTERNS.md の行数上限（100行）、サマリー生成閾値（5件）がSpec内に固定記述。実装時に設定変数化を推奨 |
| 4 | インターフェース境界 | ✅ PASS | YAMLスキーマが明確に定義されており、各コンポーネント間の入出力が独立 |
| 5 | 3ヶ月後テスト | ✅ PASS | カテゴリ追加・パターン追加はYAMLへの行追加のみ。スクリプト変更不要 |

**総合判定**: CONDITIONAL PASS

### WARN承認記録
- 軸3: 100行制限・5件閾値は実装時に `config/postmortem_settings.yaml` または環境変数で外部化する。Specレベルでは設計思想として記述するに留める。
```
