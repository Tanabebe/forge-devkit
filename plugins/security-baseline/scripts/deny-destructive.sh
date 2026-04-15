#!/bin/bash
# PreToolUse: 破壊的な Bash コマンドをブロックする
# stdin から JSON を受け取り、command を検査する
# exit 2 = ブロック（Claude Code の規約）

set -uo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

[[ -z "$COMMAND" ]] && exit 0

# 破壊的コマンドのパターン（先頭 or パイプ/セミコロン後に出現）
# 各パターンは単語境界で検査し、誤検出を防ぐ
DESTRUCTIVE_PATTERNS=(
  # ファイル/ディレクトリ削除
  '\brm\s+-rf\b'
  '\brm\s+-r\b'
  '\brm\s+-f\b'
  '\brm\s+--force\b'
  '\brm\s+--recursive\b'
  # ディスク操作
  '\bdd\s+if='
  '\bmkfs\b'
  '\bfdisk\b'
  # 権限/所有権の変更
  '\bchmod\b'
  '\bchown\b'
  # プロセス/サービス操作
  '\bkill\s+-9\b'
  '\bkillall\b'
  '\bsystemctl\s+(stop|disable|mask)\b'
  # Git の破壊的操作
  '\bgit\s+push\s+--force\b'
  '\bgit\s+push\s+-f\b'
  '\bgit\s+reset\s+--hard\b'
  '\bgit\s+clean\s+-f\b'
  '\bgit\s+checkout\s+--\s+\.\b'
  # 権限昇格
  '\bsudo\b'
  # データベース破壊
  '\bDROP\s+(TABLE|DATABASE|SCHEMA)\b'
  '\bTRUNCATE\b'
)

for PATTERN in "${DESTRUCTIVE_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qEi "$PATTERN"; then
    MATCHED=$(echo "$COMMAND" | grep -oEi "$PATTERN" | head -1)
    echo "BLOCKED: 破壊的操作が検出されました — '$MATCHED' in: $COMMAND"
    exit 2
  fi
done

exit 0
