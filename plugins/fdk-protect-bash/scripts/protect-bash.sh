#!/bin/bash
# protect-bash.sh
# PreToolUse: Bash コマンドの包括的セキュリティガード
# stdin から JSON を受け取り、command を検査する
# exit 2 = ブロック（Claude Code の規約）

set -uo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

[[ -z "$COMMAND" ]] && exit 0

# ブロック時のメッセージ出力
block() {
  echo "BLOCKED: $1 — $COMMAND"
  exit 2
}

# =============================================================================
# 1. 機密ファイルへの間接アクセス検出
#    Read/Edit/Write ツールではなく、Bash経由で .env やクレデンシャルを読もうとする操作
# =============================================================================

# .env ファイルへの間接アクセス（cat, grep, head, tail, less, more, source, sed, awk）
SENSITIVE_FILE_PATTERNS=(
  '\.env'
  '\.env\.'
  'credentials\.json'
  'serviceAccountKey.*\.json'
  '\.aws/credentials'
  '\.aws/config'
  '\.boto'
  'cloudflare\.ini'
  'wrangler\.toml'
  '\.pgpass'
  '\.netrc'
  '\.npmrc'
  '\.pypirc'
  '\.docker/config\.json'
  '\.kube/config'
  '\.tfvars'
  'terraform\.tfvars'
  '\.tfstate'
)

# ファイル内容を読み取るコマンド群
READ_COMMANDS='(cat|head|tail|less|more|bat|sed|awk|source|\.|grep|rg|ag|xargs|tee|cp|scp)'

for PATTERN in "${SENSITIVE_FILE_PATTERNS[@]}"; do
  # コマンド + 機密ファイルパターンの組み合わせを検出
  if echo "$COMMAND" | grep -qEi "${READ_COMMANDS}\s+.*${PATTERN}"; then
    block "機密ファイルへの間接アクセスが検出されました（パターン: ${PATTERN}）"
  fi
  # リダイレクト経由のアクセスも検出（< .env, > .env）
  if echo "$COMMAND" | grep -qEi "[<>]\s*\S*${PATTERN}"; then
    block "機密ファイルへのリダイレクト経由アクセスが検出されました（パターン: ${PATTERN}）"
  fi
  # find/locate で機密ファイルを検索する操作
  if echo "$COMMAND" | grep -qEi "(find|locate|fd)\s+.*${PATTERN}"; then
    block "機密ファイルの検索操作が検出されました（パターン: ${PATTERN}）"
  fi
done

# =============================================================================
# 2. ファイル/ディレクトリの破壊的操作
# =============================================================================

DESTRUCTIVE_FILE_PATTERNS=(
  '\brm\s+-rf\b'
  '\brm\s+-r\b'
  '\brm\s+-f\b'
  '\brm\s+--force\b'
  '\brm\s+--recursive\b'
  '\bdd\s+if='
  '\bmkfs\b'
  '\bfdisk\b'
  '\bchmod\b'
  '\bchown\b'
  '\bkill\s+-9\b'
  '\bkillall\b'
  '\bsystemctl\s+(stop|disable|mask)\b'
  '\bsudo\b'
)

for PATTERN in "${DESTRUCTIVE_FILE_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qEi "$PATTERN"; then
    block "破壊的なファイル操作が検出されました"
  fi
done

# =============================================================================
# 3. Git の破壊的操作
# =============================================================================

GIT_DESTRUCTIVE_PATTERNS=(
  '\bgit\s+push\s+--force\b'
  '\bgit\s+push\s+-f\b'
  '\bgit\s+push\s+.*--force-with-lease\b'
  '\bgit\s+reset\s+--hard\b'
  '\bgit\s+clean\s+-f\b'
  '\bgit\s+clean\s+-fd\b'
  '\bgit\s+checkout\s+--\s+\.'
  '\bgit\s+restore\s+--staged\s+\.'
  '\bgit\s+branch\s+-D\b'
  '\bgit\s+rebase\s+.*--force\b'
  '\bgit\s+stash\s+drop\b'
  '\bgit\s+stash\s+clear\b'
  '\bgit\s+reflog\s+expire\b'
)

for PATTERN in "${GIT_DESTRUCTIVE_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qEi "$PATTERN"; then
    block "Git の破壊的操作が検出されました"
  fi
done

# =============================================================================
# 4. Terraform の危険な操作
# =============================================================================

TERRAFORM_PATTERNS=(
  '\bterraform\s+destroy\b'
  '\bterraform\s+apply\b'
  '\bterraform\s+import\b'
  '\bterraform\s+state\s+rm\b'
  '\bterraform\s+state\s+mv\b'
  '\bterraform\s+state\s+push\b'
  '\bterraform\s+force-unlock\b'
  '\bterraform\s+taint\b'
  '\bterraform\s+untaint\b'
  '\btofu\s+destroy\b'
  '\btofu\s+apply\b'
  '\btofu\s+state\s+rm\b'
  '\bterragrunt\s+destroy\b'
  '\bterragrunt\s+apply\b'
  '\bpulumi\s+destroy\b'
  '\bpulumi\s+up\b'
)

for PATTERN in "${TERRAFORM_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qEi "$PATTERN"; then
    block "IaC の破壊的操作が検出されました（terraform/tofu/pulumi）"
  fi
done

# =============================================================================
# 5. クラウド CLI の危険な操作
# =============================================================================

CLOUD_PATTERNS=(
  # AWS CLI
  '\baws\s+.*\s+delete-'
  '\baws\s+.*\s+terminate-'
  '\baws\s+.*\s+remove-'
  '\baws\s+s3\s+rm\b'
  '\baws\s+s3\s+rb\b'
  '\baws\s+iam\s+'
  '\baws\s+sts\s+assume-role\b'
  # GCP
  '\bgcloud\s+.*\s+delete\b'
  '\bgcloud\s+projects\s+delete\b'
  '\bgcloud\s+iam\s+'
  '\bgcloud\s+auth\s+activate-service-account\b'
  # CloudFlare
  '\bwrangler\s+delete\b'
  '\bwrangler\s+d1\s+delete\b'
  '\bwrangler\s+kv:.*delete\b'
  '\bwrangler\s+r2\s+.*delete\b'
  # Vercel
  '\bvercel\s+remove\b'
  '\bvercel\s+rm\b'
  '\bvercel\s+env\s+rm\b'
  # Neon
  '\bneonctl\s+.*delete\b'
  '\bneonctl\s+.*drop\b'
  # Docker（コンテナ/イメージの一括削除）
  '\bdocker\s+system\s+prune\b'
  '\bdocker\s+volume\s+rm\b'
  '\bdocker\s+image\s+prune\b'
  # Kubernetes
  '\bkubectl\s+delete\b'
  '\bkubectl\s+drain\b'
  '\bkubectl\s+cordon\b'
  # データベース破壊
  '\bDROP\s+(TABLE|DATABASE|SCHEMA|INDEX)\b'
  '\bTRUNCATE\b'
  '\bDELETE\s+FROM\b'
)

for PATTERN in "${CLOUD_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qEi "$PATTERN"; then
    block "クラウド/インフラの危険な操作が検出されました"
  fi
done

# =============================================================================
# 6. パッケージマネージャの危険な操作（グローバルインストール等）
# =============================================================================

PKG_PATTERNS=(
  '\bnpm\s+.*-g\b'
  '\bnpm\s+.*--global\b'
  '\bpip\s+install\s+--user\b'
  '\bgem\s+install\b'
  '\bcargo\s+install\b'
  '\bcurl\s+.*|\s*sh\b'
  '\bcurl\s+.*|\s*bash\b'
  '\bwget\s+.*|\s*sh\b'
  '\bwget\s+.*|\s*bash\b'
)

for PATTERN in "${PKG_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qEi "$PATTERN"; then
    block "パッケージの危険なインストール操作が検出されました"
  fi
done

exit 0
