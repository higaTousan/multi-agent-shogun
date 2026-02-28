# upstream-sync Skill
## 概要
upstream（yohey-w/multi-agent-shogun）の最新変更をoriginにマージするSkill。

## リモート役割
- origin = higaTousan/multi-agent-shogun（**push先**）
- upstream = yohey-w/multi-agent-shogun（**pull元のみ。push禁止**）

## 手順
1. git fetch upstream（最新取得）
2. git log main..upstream/main --oneline（差分確認）
3. git merge upstream/main --no-edit（マージ）
4. 衝突発生時:
   - 殿の独自設定（CLAUDE.md, settings.yaml, queue/, context/）はlocalを優先
   - 本家の新機能・バグ修正はupstreamを優先
   - git add . && git commit（解消後）
5. テスト（必要に応じて構文チェック等）
6. git push origin main（originにのみpush）
7. **絶対にgit push upstreamしない**（D003違反）

## 衝突解消ガイドライン
- 殿固有: CLAUDE.md, config/settings.yaml, queue/*, context/*, projects/* → LOCAL優先
- スクリプト競合: 殿の修正を取り込みつつ本家の新機能も維持（手動マージ）
- 判断困難な場合: 家老に報告して判断を仰ぐ

## pr-preflight連携
push前に必ずoriginへの送信であることを確認すること（upstream誤push防止）。
