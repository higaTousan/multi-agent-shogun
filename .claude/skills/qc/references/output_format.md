# /qc 出力フォーマット

```markdown
## QC Result

Mode: design|spec|done|purpose
Overall: PASS | CONDITIONAL PASS | FAIL
Purpose Verdict: PASS | FAIL

### Acceptance Criteria
- AC1: PASS - 根拠
- AC2: FAIL - 根拠

### Findings
- PASS: ...
- WARN: ...
- FAIL: ...

### Script Validation
- report: PASS
- repo: PASS

### Escalation
- required: yes|no
- reason: ...
```

`CONDITIONAL PASS` の場合は `required: yes` とし、将軍エスカレーション結果を追記すること。
