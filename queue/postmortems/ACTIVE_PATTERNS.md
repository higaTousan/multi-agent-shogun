# ACTIVE_PATTERNS.md — QCルール集（承認済みAction Items）

**最終更新**: 2026-03-05T11:20:07
**表示パターン件数（active + pending_review）**: 5件

## ⚠️ 高優先度パターン（high/critical）

### ⏳ [info_accuracy] 不可・存在しないの判定は、代替手段・別名称を網羅的に調査してから下せ
- **由来**: cmd_211 postmortem（殿レビュー待ち）

## ⚡ 中低優先度パターン（medium/low）

### ⏳ [comm_gap] 作業指示には必ず目的（WHY）を含めよ。WHATだけの指示は禁止
- **由来**: cmd_268 postmortem（殿レビュー待ち）

### ⏳ [env_mismatch] コードは実行環境の制約に合わせよ。開発環境で動くことは本番の保証にならない
- **由来**: cmd_295 postmortem（殿レビュー待ち）

### ⏳ [scope_omission] 変更の影響範囲は、既知のファイルだけでなくgrep等で機械的に全件洗い出せ
- **由来**: cmd_295 postmortem（殿レビュー待ち）

### ⏳ [verification_gap] 正常終了の判定は、ステータスコードだけでなく出力内容も確認せよ
- **由来**: cmd_295 postmortem（殿レビュー待ち）

## 📚 アーカイブ済み教訓サマリー
| カテゴリ | 教訓1行サマリー | 関連cmd | archive日 |
|---------|----------------|---------|---------|
| - | （アーカイブなし） | - | - |
