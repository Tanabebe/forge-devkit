#!/usr/bin/env bash
# セッション開始時に .claude/settings.json の状態をチェックし、
# 未設定なら AI のコンテキストに案内指示を追加する

# プロジェクトルートを探索（git root → カレントディレクトリ）
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
SETTINGS_FILE="${PROJECT_ROOT}/.claude/settings.json"

# 案内が必要か判定
NEEDS_GUIDE=false
REASON=""

if [ ! -f "$SETTINGS_FILE" ]; then
  NEEDS_GUIDE=true
  REASON=".claude/settings.json が見つかりません。"
elif command -v jq >/dev/null 2>&1; then
  DENY_COUNT=$(jq '.permissions.deny // [] | length' "$SETTINGS_FILE" 2>/dev/null)
  if [ "$DENY_COUNT" = "0" ] || [ -z "$DENY_COUNT" ]; then
    NEEDS_GUIDE=true
    REASON=".claude/settings.json に deny ルールが設定されていません。"
  fi
fi

# 案内が必要な場合のみ additionalContext を出力
if [ "$NEEDS_GUIDE" = "true" ]; then
  cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "[forge-devkit] ${REASON} ユーザーへの最初の応答の冒頭で、次のメッセージを必ず表示してください: '⚙ forge-devkit の permissions テンプレートが未適用です。\`/fdk-security-baseline:setup\` を実行するとセキュリティ設定の適用を案内します。' この案内はセッションにつき1回だけ表示してください。"
  }
}
EOF
fi

exit 0
