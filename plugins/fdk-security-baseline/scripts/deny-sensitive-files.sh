#!/bin/bash
# PreToolUse: Read/Edit/Write 対象が機密ファイルならブロックする
# stdin から JSON を受け取り、file_path を検査する
# exit 2 = ブロック（Claude Code の規約）

set -uo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[[ -z "$FILE_PATH" ]] && exit 0

BASENAME=$(basename "$FILE_PATH")

# .env 系ファイルのブロック（.env, .env.local, .env.production 等）
if [[ "$BASENAME" =~ ^\.env(\..*)?$ ]]; then
  echo "BLOCKED: .env ファイルへのアクセスは禁止されています — $FILE_PATH"
  exit 2
fi

# その他の機密ファイルパターン
SENSITIVE_PATTERNS=(
  "credentials.json"
  "serviceAccountKey.json"
  "*.pem"
  "*.key"
  "*.p12"
  "*.pfx"
  ".npmrc"
  ".pypirc"
  "id_rsa"
  "id_ed25519"
)

for PATTERN in "${SENSITIVE_PATTERNS[@]}"; do
  # ワイルドカード対応のパターンマッチ
  # shellcheck disable=SC2254
  case "$BASENAME" in
    $PATTERN)
      echo "BLOCKED: 機密ファイルへのアクセスは禁止されています — $FILE_PATH"
      exit 2
      ;;
  esac
done

exit 0
