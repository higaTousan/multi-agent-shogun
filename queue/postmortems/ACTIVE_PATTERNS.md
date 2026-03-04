# ACTIVE_PATTERNS.md — QC照合チェックリスト

**最終更新**: 2026-03-04T20:15:27
**有効パターン件数**: 5件

## ⚠️ 高優先度パターン（high/critical）

### [info_accuracy] DeepSeek V3.2 モデルID誤判定（1つのIDで利用不可と結論）
- **関連cmd**: cmd_211
- **確認観点**: 『利用不可』は最も誤りやすい判定。バージョン違い・別名を必ず確認せよ
- **NGパターン**: 単一のモデルIDのみ調査して「不可」と結論した

## ⚡ 中優先度パターン（medium）

### [comm_gap] WHYが足軽タスクYAMLに伝わらず、目的不明のまま作業完了
- **関連cmd**: cmd_268
- **確認観点**: QC開始時にタスクYAMLのacceptance_criteriaとparent_cmd purposeを照合せよ
- **チェック**: 足軽タスクYAMLにparent_cmd purposeフィールドを必須化

### [env_mismatch] Python 3.10+型構文をlaunchd（Python 3.9）で使用
- **関連cmd**: cmd_295
- **確認観点**: launchd実行系は /usr/bin/python3 = 3.9.6。X|None禁止、Optional[X]を使え
- **チェック**: launchd系Pythonスクリプトは Optional[X] を必須とするlintルールを追加

### [scope_omission] weekly/monthly/yearly Gemini移行時にzettelkastenが対象外
- **関連cmd**: cmd_295
- **確認観点**: モデル移行時は全スクリプト横断でgrep確認せよ
- **チェック**: モデル移行タスクに 'rg -n model_id scripts/' の実行証跡を必須化

### [verification_gap] launchdジョブのexit_code=0のみ確認でログ内容未チェック
- **関連cmd**: cmd_295
- **確認観点**: exit_code=0は『プロセスが死ななかった』だけ。ログ内容も必ず確認せよ
- **チェック**: launchd検証テンプレートに『ログ先頭/末尾20行』添付を必須化

