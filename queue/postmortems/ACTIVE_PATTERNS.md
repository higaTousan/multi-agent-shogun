# ACTIVE_PATTERNS.md — QC照合チェックリスト

**最終更新**: 2026-03-04T20:11:58
**有効パターン件数**: 4件

## ⚠️ 高優先度パターン（high/critical）

（該当なし）

## ⚡ 中優先度パターン（medium）

### [info_accuracy] DeepSeek V3.2 モデルID誤判定（1つのIDで利用不可と結論）
- **関連cmd**: cmd_211
- **確認観点**: 『利用不可』は最も誤りやすい判定。バージョン違い・別名を必ず確認せよ
- **チェック**: CLAUDE.md に『外部API調査ルール』追加（モデルID全列挙・ネガティブ判定のエビデンス必須）

### [env_mismatch] Python 3.10+型構文をlaunchd（Python 3.9）で使用
- **関連cmd**: cmd_295
- **確認観点**: launchd実行系は /usr/bin/python3 = 3.9.6。X|None禁止、Optional[X]を使え
- **チェック**: launchd系Pythonスクリプトは Optional[X] を必須とするlintルールを追加

### [verification_gap] launchdジョブのexit_code=0のみ確認でログ内容未チェック
- **関連cmd**: cmd_295
- **確認観点**: exit_code=0は『プロセスが死ななかった』だけ。ログ内容も必ず確認せよ
- **チェック**: launchd検証テンプレートに『ログ先頭/末尾20行』添付を必須化

