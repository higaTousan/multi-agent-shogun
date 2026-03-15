---
name: qc
description: |
  QCを1本化して実行する統合スキル。design/spec/done/purpose の4モードを持ち、
  共通のスクリプト検証と、曖昧判定時の将軍エスカレーションを含む。
  「/qc」「QC」「品質確認」「完了前チェック」で起動。
---

# /qc - 統合QC

`/qc` は従来の `design-review` `spec-impl-check` `done-checklist` を置き換える統合スキルである。
必ず以下の順で進めること。前段が FAIL の場合、後続へ進むな。

## 呼び出し

```text
/qc <design|spec|done|purpose> [対象]
```

対象省略時は、現在の task / branch / report を読む。

## 4フェーズ

### Phase 1: スクリプト検証

まず `scripts/qc_validate.sh report --report <report>` を実行し、QCレポートの最低条件を機械検証する。
必要に応じて `scripts/qc_validate.sh repo` で15項目の環境検証も行う。

- FAIL: 直ちに差し戻し
- CONDITIONAL: `--escalate` を付けて再実行し、将軍へ相談
- PASS: Phase 2へ進む

### Phase 2: モード別確認

- `design`: 設計品質5軸 + `queue/postmortems/ACTIVE_PATTERNS.md` 突合
- `spec`: Specと実装の逐語突合
- `done`: 完了前6項目チェック
- `purpose`: `queue/shogun_to_karo.yaml` の `purpose` / `acceptance_criteria` 観点で、成果物が本当にユーザー目的を満たすか確認

詳細手順は `references/procedure.md` を参照。

### Phase 3: 判定整理

結果を `PASS / CONDITIONAL PASS / FAIL` でまとめる。

- FAIL: 修正必須
- CONDITIONAL PASS: 将軍エスカレーション必須
- PASS: Phase 4へ進む

### Phase 4: 完了前確認

`done` モード、または完了報告前の最終QCでは `scripts/qc_validate.sh repo` を併用し、
機械的な見落としを潰す。最終出力は `references/output_format.md` 形式に従う。

## 将軍エスカレーション

以下は軍師単独で許容するな。

- `CONDITIONAL PASS`
- 「許容」「概ね」「暫定」「ただし」等の曖昧判定
- SKIPを含むテスト結果
- DB変更 / API変更 / 認証変更 / セキュリティ疑義

実行例:

```bash
bash scripts/qc_validate.sh report \
  --report queue/reports/gunshi_report.md \
  --task-id cmd_328 \
  --escalate \
  --from gunshi
```

## 絶対ルール

- report未検証で PASS を出すな
- `purpose` モードを省略して「技術的には動く」で済ませるな
- 曖昧判定を見つけたら必ず将軍に回せ
- `ACTIVE_PATTERNS.md` を読まずに design 判定するな
