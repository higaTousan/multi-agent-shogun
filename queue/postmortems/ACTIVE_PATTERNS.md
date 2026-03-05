# ACTIVE_PATTERNS.md — QC照合チェックリスト

**最終更新**: 2026-03-05T11:05:17
**表示パターン件数（active + pending_review）**: 5件

## ⚠️ 高優先度パターン（high/critical）

### ⏳ [info_accuracy] 足軽が旧モデルIDのみ調査し『利用不可』と誤判定し、殿の手動確認で誤りが発覚した。
- **関連cmd**: cmd_211
- **ステータス**: pending_review
- **教訓**: 殿の最終確認で誤推奨が本実装へ流入する前に停止できた
- **NGパターン**: 足軽1号が旧ID deepseek-v3-0324 の単一確認だけで不可判定した
- **主要Action**: 外部API調査時は関連モデルIDを全列挙し、単一IDで不可判定しないチェックを必須化

## ⚡ 中低優先度パターン（medium/low）

### ⏳ [comm_gap] 伝達過程でWHYが消失し、足軽が『ファイル生成』のみを完了条件と誤解した。
- **関連cmd**: cmd_268
- **ステータス**: pending_review
- **教訓**: 殿レビューで期待との乖離を早期に止められた
- **主要Action**: 足軽タスクYAMLに parent_cmd purpose の明記を必須化

### ⏳ [env_mismatch] Python 3.10+専用型構文をlaunchd（Python 3.9）で使用し実行エラーを起こした。
- **関連cmd**: cmd_295
- **ステータス**: pending_review
- **教訓**: ログ調査で環境差異を具体的に特定できた
- **主要Action**: launchd対象Pythonは3.9互換記法（Optional/Union）を標準化

### ⏳ [scope_omission] weekly/monthly移行時にzettelkastenスクリプトが対象外のまま残存した。
- **関連cmd**: cmd_295
- **ステータス**: pending_review
- **教訓**: 調査フェーズで漏れを特定し、再修正の起点を作れた
- **主要Action**: モデル移行タスクは rg による対象ファイル全列挙を必須化

### ⏳ [verification_gap] launchdジョブのexit_code=0のみ確認し、ログ内容のエラー兆候を見逃した。
- **関連cmd**: cmd_295
- **ステータス**: pending_review
- **教訓**: 後続調査でログ確認の重要性を定量的に示せた
- **主要Action**: launchd検証は exit_code とログ本文（先頭/末尾20行）を必須化

## 📚 アーカイブ済み教訓サマリー
| カテゴリ | 教訓1行サマリー | 関連cmd | archive日 |
|---------|----------------|---------|---------|
| - | （アーカイブなし） | - | - |
