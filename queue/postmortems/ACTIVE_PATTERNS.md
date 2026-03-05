# ACTIVE_PATTERNS.md — QCルール集（承認済みAction Items）

**最終更新**: 2026-03-05T11:09:09
**表示パターン件数（active + pending_review）**: 5件

## ⚠️ 高優先度パターン（high/critical）

### ⏳ [info_accuracy] 外部API調査時は関連モデルIDを全列挙し、単一IDで不可判定しないチェックを必須化
- **由来**: cmd_211 postmortem（殿レビュー待ち）

## ⚡ 中低優先度パターン（medium/low）

### ⏳ [comm_gap] 足軽タスクYAMLに parent_cmd purpose の明記を必須化
- **由来**: cmd_268 postmortem（殿レビュー待ち）

### ⏳ [env_mismatch] launchd対象Pythonは3.9互換記法（Optional/Union）を標準化
- **由来**: cmd_295 postmortem（殿レビュー待ち）

### ⏳ [scope_omission] モデル移行タスクは rg による対象ファイル全列挙を必須化
- **由来**: cmd_295 postmortem（殿レビュー待ち）

### ⏳ [verification_gap] launchd検証は exit_code とログ本文（先頭/末尾20行）を必須化
- **由来**: cmd_295 postmortem（殿レビュー待ち）

## 📚 アーカイブ済み教訓サマリー
| カテゴリ | 教訓1行サマリー | 関連cmd | archive日 |
|---------|----------------|---------|---------|
| - | （アーカイブなし） | - | - |
