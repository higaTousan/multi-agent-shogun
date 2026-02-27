---
name: pr-preflight
description: PR作成前の安全チェック。push先がorigin（higaTousan）であること、upstreamへの誤送信防止、force push検知を確認する。「pr-preflight」「PR作成前」「PR送信前チェック」で起動。gh pr createを実行する前に必ず使用。
---

# /pr-preflight - PR送信前安全チェック

## Overview

`gh pr create` の実行前に、push先・remote設定・ブランチ状態を検証し、
upstream（本家）への誤送信を未然に防ぐ。

**背景**: cmd_269でSpec PRがupstream（yohey-w/multi-agent-shogun）に誤送信された。
ルールで守れなかった事例のため、仕組みで封じる（殿の直命 2026-02-28追加）。

## When to Use

- `gh pr create` を実行する**直前**（必須）
- PR作成をタスクに含むすべてのエージェント（足軽・軍師・家老を問わない）
- ブランチをpushしてPRを出す前

## Instructions

### STEP 1: 現在のリポジトリとremote設定を確認

```bash
git remote -v
```

確認項目:
- `origin (push)` が `higaTousan/*` であること
- `upstream (push)` が `no_push_allowed` であること（封鎖済みか）

### STEP 2: 現在のブランチとpush状態を確認

```bash
git branch --show-current
git status
git log --oneline -3
```

確認項目:
- 作業ブランチが main/master でないこと（直接PRは原則禁止）
- 未コミットの変更が残っていないこと
- ブランチがoriginにpush済みか

```bash
git log origin/$(git branch --show-current) --oneline -1 2>&1 || echo "originにpush未実施"
```

### STEP 3: force pushフラグが不要であることを確認

`gh pr create` コマンドに `--force` フラグが含まれていないことを目視確認。
force pushが必要な場合は `--force-with-lease` を使用すること。

### STEP 4: PR送信先リポジトリを確認

```bash
gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "ghコマンド確認不可"
```

`gh pr create` に `--repo` フラグを指定する場合:
- `higaTousan/*` であること
- `yohey-w/*` (upstream) への送信は**絶対禁止**

### STEP 5: チェックリストテーブルの出力

```
## pr-preflight 結果: {ブランチ名} → {送信先リポジトリ}

| チェック | 項目 | 確認内容 | 結果 | 判定 |
|---------|------|---------|------|------|
| A | origin push URL | higaTousan/* であること | {確認結果} | ✅/❌ |
| B | upstream push封鎖 | no_push_allowed であること | {確認結果} | ✅/❌/➖ |
| C | ブランチがorigin push済み | origin/{branch} が存在 | {確認結果} | ✅/❌ |
| D | force pushなし | --force フラグなし | {確認結果} | ✅/❌ |
| E | PR送信先がorigin | higaTousan/* 指定 | {確認結果} | ✅/❌ |

**総合判定**: PASS / BLOCK

（判定基準）
- PASS: 全項目が OK または N/A
- BLOCK: NG が 1 件以上

### BLOCK項目一覧（要対処）
- [ ] チェックN: {問題内容} → {必要なアクション}
```

### STEP 6: 判定の適用

- **PASS**: `gh pr create` に進んでよい
- **BLOCK**: **PR作成禁止**。BLOCK項目を解消してから再チェックせよ

## Examples

### 例: PASS ケース

```
## pr-preflight 結果: feat/cmd_275-upstream-block → higaTousan/multi-agent-shogun

| チェック | 項目 | 確認内容 | 結果 | 判定 |
|---------|------|---------|------|------|
| A | origin push URL | higaTousan/multi-agent-shogun.git | OK | ✅ |
| B | upstream push封鎖 | no_push_allowed | 封鎖済み | ✅ |
| C | ブランチがorigin push済み | origin/feat/cmd_275 存在確認 | push済み | ✅ |
| D | force pushなし | --force フラグなし | なし | ✅ |
| E | PR送信先がorigin | higaTousan/multi-agent-shogun 指定 | OK | ✅ |

**総合判定**: PASS
```

### 例: BLOCK ケース（upstream誤送信を検知）

```
## pr-preflight 結果: spec/cmd269-zettelkasten → yohey-w/multi-agent-shogun

| チェック | 項目 | 確認内容 | 結果 | 判定 |
|---------|------|---------|------|------|
| A | origin push URL | higaTousan/multi-agent-shogun.git | OK | ✅ |
| B | upstream push封鎖 | no_push_allowed | 封鎖済み | ✅ |
| C | ブランチがorigin push済み | origin/spec/cmd269 存在確認 | push済み | ✅ |
| D | force pushなし | --force フラグなし | なし | ✅ |
| E | PR送信先がorigin | yohey-w/multi-agent-shogun 指定 ← 誤り | upstream指定！ | ❌ |

**総合判定**: BLOCK

### BLOCK項目一覧（要対処）
- [ ] チェックE: --repo yohey-w/multi-agent-shogun は upstream（本家）への誤送信 → --repo higaTousan/multi-agent-shogun に修正せよ
```

## Guidelines

1. **必ず `gh pr create` の直前に実行**: 「後で確認」は認めない
2. **BLOCK=PR禁止**: NG1件でもあればPR作成を止める。BLOCK状態のまま強行することは殿への不敬
3. **B項目（upstream封鎖）が ➖ N/A の場合**: upstream remoteが存在しないリポジトリのみN/A。upstreamが設定されているリポジトリでは必ず確認すること
4. **`--repo` フラグの確認**: `gh pr create` に `--repo` フラグを付ける場合は特に注意。付けない場合はカレントリポジトリのoriginが使われる
5. **前例（cmd_269）**: spec/cmd269-zettelkasten ブランチのPRをupstream（yohey-w）に送った。殿がお怒りになりcloseされた。このSkillはその再発防止のために作られた。
