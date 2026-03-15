# /qc 手順詳細

## 共通入力

1. task YAML
2. parent cmd (`queue/shogun_to_karo.yaml`)
3. Spec文書
4. 実装ファイル
5. QCレポート

## design

1. 命名の抽象度
2. 差し替え耐性
3. 設定の外部化
4. インターフェース境界
5. 3ヶ月後テスト
6. `queue/postmortems/ACTIVE_PATTERNS.md` 突合

## spec

1. `spec_doc` を読む
2. 実装ファイルを読む
3. 変数名 / 入出力 / ファイルパス / 文言を突合
4. `MATCH / PARTIAL / MISMATCH / N/A` を記録

## done

1. 成果物の実在
2. 構文チェック
3. テスト結果
4. Spec準拠
5. インフラ稼働
6. git push

## purpose

1. parent cmd の `purpose` を要約する
2. `acceptance_criteria` を箇条書きで列挙する
3. 成果物がエンドユーザー価値を満たすか判定する
4. 技術的達成とユーザー目的達成がズレる場合は `purpose_gap` を明記する

## report 検証

`scripts/qc_validate.sh report --report <path>` は以下を検査する。

1. overall verdict があるか
2. purpose verdict があるか
3. acceptance criteria に PASS/FAIL が付いているか
4. 未検証項目が残っていないか
5. 曖昧表現がある場合は escalate が必要か

## repo 検証

`scripts/qc_validate.sh repo` は15項目の機械検査を行う。対象外の項目は `SKIP` ではなく `N/A` を理由付きで扱う。
