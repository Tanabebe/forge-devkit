#!/bin/bash
# セッション開始時に .claude/settings.json の存在と deny ルールをチェックする
# forge-devkit の permissions テンプレートが未適用なら案内メッセージを出力

# プロジェクトルートを探索（git root → カレントディレクトリ）
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

SETTINGS_FILE="${PROJECT_ROOT}/.claude/settings.json"

# .claude/settings.json が存在しない場合
if [ ! -f "$SETTINGS_FILE" ]; then
  echo "" >&2
  echo "[forge-devkit] .claude/settings.json が見つかりません。" >&2
  echo "[forge-devkit] /setup-permissions を実行すると、セキュリティ設定（deny ルール）の適用を案内します。" >&2
  echo "" >&2
  exit 0
fi

# settings.json は存在するが、deny ルールが含まれていない場合
if command -v jq >/dev/null 2>&1; then
  DENY_COUNT=$(jq '.permissions.deny // [] | length' "$SETTINGS_FILE" 2>/dev/null)
  if [ "$DENY_COUNT" = "0" ] || [ -z "$DENY_COUNT" ]; then
    echo "" >&2
    echo "[forge-devkit] .claude/settings.json に deny ルールが設定されていません。" >&2
    echo "[forge-devkit] /setup-permissions を実行すると、セキュリティ設定の適用を案内します。" >&2
    echo "" >&2
  fi
fi

exit 0
