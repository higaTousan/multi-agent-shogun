#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
POSTMORTEM_DIR="$ROOT_DIR/queue/postmortems"
SUMMARY_DIR="$POSTMORTEM_DIR/summaries"
OUTPUT_FILE="$POSTMORTEM_DIR/ACTIVE_PATTERNS.md"

mkdir -p "$POSTMORTEM_DIR" "$SUMMARY_DIR"

extract_scalar() {
  local key="$1"
  local file="$2"
  grep -m1 "^[[:space:]]*${key}:" "$file" | sed -E "s/^[[:space:]]*${key}:[[:space:]]*//; s/^\"(.*)\"$/\1/"
}

extract_summary() {
  local file="$1"
  local summary
  summary="$(extract_scalar "summary" "$file" || true)"
  if [ -n "$summary" ]; then
    echo "$summary"
    return
  fi
  extract_scalar "title" "$file" || true
}

extract_first_list_item_after_key() {
  local key="$1"
  local file="$2"
  local line
  line="$(grep -n "^[[:space:]]*${key}:" "$file" | head -1 | cut -d: -f1 || true)"
  if [ -z "$line" ]; then
    echo ""
    return
  fi
  sed -n "$((line+1)),$((line+40))p" "$file" | grep -m1 '^[[:space:]]*-[[:space:]]*"' | sed -E 's/^[[:space:]]*-[[:space:]]*"(.*)"/\1/'
}

extract_why1() {
  local file="$1"
  grep -m1 '^[[:space:]]*-[[:space:]]*why1:' "$file" | sed -E 's/^[[:space:]]*-[[:space:]]*why1:[[:space:]]*"(.*)"/\1/'
}

extract_first_action_item() {
  local file="$1"
  local line
  line="$(grep -n '^[[:space:]]*action_items:' "$file" | head -1 | cut -d: -f1 || true)"
  if [ -z "$line" ]; then
    echo ""
    return
  fi
  sed -n "$((line+1)),$((line+80))p" "$file" | grep -m1 '^[[:space:]]*-[[:space:]]*action:' | sed -E 's/^[[:space:]]*-[[:space:]]*action:[[:space:]]*"(.*)"/\1/'
}

extract_first_lesson_any() {
  local file="$1"
  local line
  line="$(grep -n '^[[:space:]]*lessons_learned:' "$file" | head -1 | cut -d: -f1 || true)"
  if [ -z "$line" ]; then
    echo ""
    return
  fi
  sed -n "$((line+1)),$((line+80))p" "$file" | grep -m1 '^[[:space:]]*-[[:space:]]*"' | sed -E 's/^[[:space:]]*-[[:space:]]*"(.*)"/\1/'
}

build_candidate_list() {
  : > /tmp/postmortem_candidates.txt
  local f status ts
  for f in "$POSTMORTEM_DIR"/*.yaml; do
    [ -f "$f" ] || continue
    status="$(extract_scalar "status" "$f" || true)"
    if [ "$status" = "active" ] || [ "$status" = "pending_review" ]; then
      ts="$(extract_scalar "timestamp" "$f" || true)"
      echo "${ts}|${f}|${status}" >> /tmp/postmortem_candidates.txt
    fi
  done
  sort /tmp/postmortem_candidates.txt > /tmp/postmortem_candidates_sorted.txt
}

render_archive_summary_section() {
  local f cat lesson cmd adate
  : > /tmp/postmortem_archive_rows.md

  for f in "$SUMMARY_DIR"/*.yaml; do
    [ -f "$f" ] || continue
    cat="$(extract_scalar "category" "$f" || true)"
    lesson="$(extract_first_lesson_any "$f" || true)"
    cmd="$(extract_scalar "cmd_id" "$f" || true)"
    adate="$(date -r "$f" '+%Y-%m' 2>/dev/null || date '+%Y-%m')"
    [ -n "$lesson" ] || lesson="(教訓抽出不可)"
    echo "| [${cat}] | ${lesson} | ${cmd} | ${adate} |" >> /tmp/postmortem_archive_rows.md
  done
}

render_markdown() {
  local now total f sev cat cmd status marker action origin_note
  now="$(date '+%Y-%m-%dT%H:%M:%S')"
  total="$(wc -l < /tmp/postmortem_candidates_sorted.txt | tr -d ' ')"

  : > /tmp/postmortem_high.md
  : > /tmp/postmortem_mid_low.md

  while IFS='|' read -r _ f status; do
    [ -f "$f" ] || continue
    sev="$(extract_scalar "severity" "$f" || true)"
    cat="$(extract_scalar "category" "$f" || true)"
    cmd="$(extract_scalar "cmd_id" "$f" || true)"
    action="$(extract_first_action_item "$f" || true)"

    if [ "$status" = "pending_review" ]; then
      marker="⏳"
      origin_note="殿レビュー待ち"
    else
      marker="✅"
      origin_note="殿承認済み"
    fi

    if [ "$sev" = "critical" ] || [ "$sev" = "high" ]; then
      {
        echo "### ${marker} [${cat}] ${action}"
        echo "- **由来**: ${cmd} postmortem（${origin_note}）"
        echo ""
      } >> /tmp/postmortem_high.md
    else
      {
        echo "### ${marker} [${cat}] ${action}"
        echo "- **由来**: ${cmd} postmortem（${origin_note}）"
        echo ""
      } >> /tmp/postmortem_mid_low.md
    fi
  done < /tmp/postmortem_candidates_sorted.txt

  render_archive_summary_section

  {
    echo "# ACTIVE_PATTERNS.md — QCルール集（承認済みAction Items）"
    echo ""
    echo "**最終更新**: ${now}"
    echo "**表示パターン件数（active + pending_review）**: ${total}件"
    echo ""
    echo "## ⚠️ 高優先度パターン（high/critical）"
    echo ""
    if [ -s /tmp/postmortem_high.md ]; then
      cat /tmp/postmortem_high.md
    else
      echo "（該当なし）"
      echo ""
    fi
    echo "## ⚡ 中低優先度パターン（medium/low）"
    echo ""
    if [ -s /tmp/postmortem_mid_low.md ]; then
      cat /tmp/postmortem_mid_low.md
    else
      echo "（該当なし）"
      echo ""
    fi
    echo "## 📚 アーカイブ済み教訓サマリー"
    echo "| カテゴリ | 教訓1行サマリー | 関連cmd | archive日 |"
    echo "|---------|----------------|---------|---------|"
    if [ -s /tmp/postmortem_archive_rows.md ]; then
      cat /tmp/postmortem_archive_rows.md
    else
      echo "| - | （アーカイブなし） | - | - |"
    fi
  } > "$OUTPUT_FILE"
}

move_old_medium_or_low() {
  local candidate="" f sev
  while IFS='|' read -r _ f _status; do
    [ -f "$f" ] || continue
    sev="$(extract_scalar "severity" "$f" || true)"
    if [ "$sev" = "medium" ] || [ "$sev" = "low" ]; then
      candidate="$f"
      break
    fi
  done < /tmp/postmortem_candidates_sorted.txt

  if [ -n "$candidate" ]; then
    mv "$candidate" "$SUMMARY_DIR/"
    echo "moved_to_summaries: $(basename "$candidate")"
    return 0
  fi

  return 1
}

build_candidate_list
render_markdown
line_count="$(wc -l < "$OUTPUT_FILE" | tr -d ' ')"

while [ "$line_count" -gt 100 ]; do
  if ! move_old_medium_or_low >/tmp/update_active_patterns_move.log; then
    break
  fi
  build_candidate_list
  render_markdown
  line_count="$(wc -l < "$OUTPUT_FILE" | tr -d ' ')"
done

echo "updated: $OUTPUT_FILE"
echo "line_count: $line_count"
