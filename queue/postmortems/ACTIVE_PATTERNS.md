# ACTIVE_PATTERNS.md — QC照合チェックリスト

**最終更新**: 2026-03-04T20:10:00
**有効パターン件数**: 5件
**管理ルール**: 100行以内を維持。resolved後はsummaries/へ移動。

---

## ⚠️ 高優先度パターン（high）

### [info_accuracy] 外部APIモデルIDの複数バージョン確認
- **関連cmd**: cmd_211
- **確認観点**: 単一のモデルIDだけ調べて「利用不可」と判定していないか？
- **NGパターン**: `deepseek-v3-0324` → 「利用不可」と判断（実際は `deepseek/deepseek-v3.2` が利用可能だった）
- **チェック**: プロバイダーのモデル一覧ページで関連モデルを全列挙してから判断せよ

---

## ⚡ 中優先度パターン（medium）

### [env_mismatch] Python実行環境のバージョン確認
- **関連cmd**: cmd_295
- **確認観点**: launchd実行系（`/usr/bin/python3` = 3.9.6）とInteractive/Homebrewのpythonは別物
- **NGパターン**: `X | None` 型構文（Python 3.10+のみ有効）をlaunchd環境で使用
- **チェック**: `python3 --version` をスクリプト冒頭で確認 or `sys.version_info >= (3, 10)` をアサート

### [verification_gap] launchdジョブのログ内容確認
- **関連cmd**: cmd_295
- **確認観点**: exit_code=0は「プロセスが死ななかった」を意味するだけ。実際の動作はログで確認せよ
- **NGパターン**: exit_code=0のみ確認してログファイルの内容を見ない
- **チェック**: `tail -n 50 {ログファイル}` で実際の出力を目視確認

### [scope_omission] モデル/ツール移行時の影響範囲横断確認
- **関連cmd**: cmd_295（zettelkastenスクリプトがOllama参照のまま残存）
- **確認観点**: 対象ファイル一覧だけでなく、リポジトリ全体で旧ツール参照が残っていないか
- **NGパターン**: タスクで指定されたファイルのみ変更し、他スクリプトの参照確認をしない
- **チェック**: `grep -r "ollama\|OLLAMA" . --include="*.sh" --include="*.py" --include="*.yaml"`

### [comm_gap] WHYが足軽タスクYAMLに伝わっているか確認
- **関連cmd**: cmd_268, cmd_274
- **確認観点**: 足軽タスクYAMLのacceptance_criteriaに「目的の達成」が含まれているか
- **NGパターン**: acceptance_criteriaが「ファイルが存在すること」のみ → 目的不明のまま作業完了
- **チェック**: QC開始時にタスクYAMLのacceptance_criteriaとparent_cmd purposeを照合せよ

---

## 使い方（軍師QC時）

1. QC開始時にこのファイルを読み込む（step 2.5: instructions/gunshi.mdに固定）
2. 各パターンをチェックリストとして照合
3. QCレポートの `postmortem_patterns_checked` フィールドに照合結果を記載
4. 新規パターン発見時は `/postmortem` Skillで記録 → このファイルが自動更新される
