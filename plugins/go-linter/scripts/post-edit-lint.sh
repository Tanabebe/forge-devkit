#!/bin/bash
# PostToolUse: .go ファイル編集後に golangci-lint を実行する
# exit 0 固定: lint はあくまで追加情報。ブロックしない。

set -uo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[[ -z "$FILE_PATH" ]] && exit 0
[[ ! -f "$FILE_PATH" ]] && exit 0

# .go ファイル以外はスキップ
[[ "$FILE_PATH" != *.go ]] && exit 0

# golangci-lint が存在するか確認
if ! command -v golangci-lint &>/dev/null; then
  echo "⚠ golangci-lint が見つかりません。インストール: https://golangci-lint.run/welcome/install/"
  exit 0
fi

# 対象ファイルのディレクトリで lint 実行
DIR=$(dirname "$FILE_PATH")
RESULT=$(cd "$DIR" && golangci-lint run --timeout=30s ./... 2>&1) || true

if [[ -n "$RESULT" ]]; then
  echo "## golangci-lint: $(basename "$FILE_PATH")"
  echo '```'
  echo "$RESULT"
  echo '```'
fi

exit 0
