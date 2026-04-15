#!/bin/bash
# PostToolUse: TS/TSX/JS/JSX ファイル編集後に oxlint（or eslint）を実行する
# exit 0 固定: lint はあくまで追加情報。ブロックしない。

set -uo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[[ -z "$FILE_PATH" ]] && exit 0
[[ ! -f "$FILE_PATH" ]] && exit 0

# 対象拡張子の判定
case "$FILE_PATH" in
  *.ts|*.tsx|*.js|*.jsx) ;;
  *) exit 0 ;;
esac

REAL_PATH=$(realpath "$FILE_PATH" 2>/dev/null || echo "$FILE_PATH")

# プロジェクトルートを探す（package.json がある最も近い親ディレクトリ）
find_project_root() {
  local dir="$1"
  while [[ "$dir" != "/" ]]; do
    [[ -f "$dir/package.json" ]] && echo "$dir" && return
    dir=$(dirname "$dir")
  done
  echo ""
}

PROJECT_ROOT=$(find_project_root "$(dirname "$REAL_PATH")")
[[ -z "$PROJECT_ROOT" ]] && exit 0

# oxlint を優先、なければ eslint にフォールバック
LINTER=""
LINTER_NAME=""

if [[ -x "$PROJECT_ROOT/node_modules/.bin/oxlint" ]]; then
  LINTER="$PROJECT_ROOT/node_modules/.bin/oxlint"
  LINTER_NAME="oxlint"
elif command -v oxlint &>/dev/null; then
  LINTER="oxlint"
  LINTER_NAME="oxlint"
elif [[ -x "$PROJECT_ROOT/node_modules/.bin/eslint" ]]; then
  LINTER="$PROJECT_ROOT/node_modules/.bin/eslint"
  LINTER_NAME="eslint"
elif command -v eslint &>/dev/null; then
  LINTER="eslint"
  LINTER_NAME="eslint"
fi

if [[ -z "$LINTER" ]]; then
  echo "⚠ oxlint / eslint が見つかりません。npm install oxlint --save-dev を推奨。"
  exit 0
fi

RESULT=$(cd "$PROJECT_ROOT" && $LINTER "$REAL_PATH" 2>&1) || true

if [[ -n "$RESULT" ]]; then
  echo "## ${LINTER_NAME}: $(basename "$FILE_PATH")"
  echo '```'
  echo "$RESULT"
  echo '```'
fi

exit 0
