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
  'credentials\.json'
  'serviceAccountKey'
  '\.aws/'
  '\.boto'
  'cloudflare\.ini'
  'wrangler\.toml'
  '\.pgpass'
  '\.netrc'
  '\.npmrc'
  '\.pypirc'
  '\.docker/config'
  '\.kube/config'
  '\.tfvars'
  '\.tfstate'
  '\.pem'
  '\.key'
  '\.p12'
  '\.pfx'
  '\.keystore'
  '\.jks'
  'id_rsa'
  'id_ed25519'
  'id_ecdsa'
  '\.cloudflared'
  '\.neon'

  # ホスティングサービスの内部設定（トークン・プロジェクトIDを含むもの）
  '\.vercel/'
  '\.netlify/'
  '\.firebaserc'
  'firebase-debug\.log'
  '\.railway/'
  '\.supabase/'
  'amplify/\.config'
)

for PATTERN_CHECK in "${SENSITIVE_PATTERNS[@]}"; do
  if echo "$ALL_FIELDS" | grep -qEi "$PATTERN_CHECK"; then
    echo "BLOCKED: 機密ファイルの検索が検出されました（パターン: ${PATTERN_CHECK}）"
    exit 2
  fi
done

exit 0
