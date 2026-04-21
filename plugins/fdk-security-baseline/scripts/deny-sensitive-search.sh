#!/bin/bash
# PreToolUse: Glob/Grep で機密ファイルを検索する操作をブロックする
# stdin から JSON を受け取り、pattern / path / glob を検査する
# exit 2 = ブロック（Claude Code の規約）

set -uo pipefail

INPUT=$(cat)

# ツール名を取得
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Glob / Grep の各フィールドを取得
PATTERN=$(echo "$INPUT" | jq -r '.tool_input.pattern // empty')
PATH_FIELD=$(echo "$INPUT" | jq -r '.tool_input.path // empty')
GLOB_FIELD=$(echo "$INPUT" | jq -r '.tool_input.glob // empty')

# 検査対象のすべてのフィールドを結合
ALL_FIELDS="${PATTERN} ${PATH_FIELD} ${GLOB_FIELD}"

# 機密ファイルパターン
SENSITIVE_PATTERNS=(
  '\.env'
  'serviceAccountKey'
  'application_default_credentials\.json'
  '\.aws/credentials'
  '\.aws/config'
  '\.aws/sso/cache'
  '\.aws/cli/cache'
  '\.boto'
  'cloudflare\.ini'
  '\.dev\.vars'
  '\.pgpass'
  '\.mylogin\.cnf'
  '\.my\.cnf'
  '\.netrc'
  '\.npmrc'
  '\.pypirc'
  '\.docker/config'
  '\.kube/config'
  '\.tfvars'
  '\.tfstate'
  '\.terraformrc'
  '\.pem'
  '\.key'
  '\.p12'
  '\.pfx'
  '\.keystore'
  '\.jks'
  'id_rsa'
  'id_ed25519'
  'id_ecdsa'
  'id_dsa'
  '\.cloudflared'
  '\.sentryclirc'
  'sentry\.properties'

  # CLI auth 保存先（各公式ドキュメントで確認済みのパス）
  '\.railway/config'
  '\.supabase/access-token'
  '\.config/neonctl/credentials'
  '\.config/configstore/firebase-tools'
  '\.config/gcloud/application_default_credentials'
)

for PATTERN_CHECK in "${SENSITIVE_PATTERNS[@]}"; do
  if echo "$ALL_FIELDS" | grep -qEi "$PATTERN_CHECK"; then
    echo "BLOCKED: 機密ファイルの検索が検出されました（パターン: ${PATTERN_CHECK}）"
    exit 2
  fi
done

exit 0
