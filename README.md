# forge-devkit

Web 開発者向けの Claude Code セキュリティ・品質プラグインコレクション。

バックエンドは Go（golangci-lint）、フロントエンドは TypeScript / JavaScript（oxlint / ESLint）の自動 lint に対応。機密ファイル保護と破壊的操作ブロックで開発環境の安全性を担保する。

## プラグイン一覧

### security-baseline

`.env`、クレデンシャル、秘密鍵などの機密ファイルへの Read / Edit / Write をブロックする。Glob / Grep による機密ファイルの検索もブロック。`rm -rf`、`sudo`、`git push --force` 等の破壊的 Bash コマンドもブロック。

### protect-bash

Bash ツール経由での間接的な機密ファイルアクセスを検出・ブロックする。`cat .env`、`grep credentials.json` のような操作に加え、Terraform / クラウド CLI（AWS, GCP, CloudFlare, Vercel, Neon）/ Git の危険な操作を包括的にガード。

### go-linter

`.go` ファイル編集後に [golangci-lint](https://golangci-lint.run/) を自動実行する。対象ファイルのディレクトリで `golangci-lint run ./...` を実行し、結果を追加コンテキストとして表示する。ブロックはしない。

golangci-lint 未インストール時は警告メッセージのみ表示。

### frontend-linter

`.ts` / `.tsx` / `.js` / `.jsx` ファイル編集後にリンターを自動実行する。

リンターの検出順:

1. プロジェクトの `node_modules/.bin/oxlint`
2. グローバルの `oxlint`
3. プロジェクトの `node_modules/.bin/eslint`
4. グローバルの `eslint`

プロジェクトルートは編集ファイルから `package.json` を遡って自動検出する。`package.json` が見つからない場合はスキップされる。

## インストール

### 方法 1: マーケットプレイスから（推奨）

Claude Code セッション内で以下を実行:

```
/plugin marketplace add Tanabebe/forge-devkit
```

マーケットプレイス追加後、個別にインストール:

```
/plugin install security-baseline@forge-devkit
```

```
/plugin install protect-bash@forge-devkit
```

```
/plugin install go-linter@forge-devkit
```

```
/plugin install frontend-linter@forge-devkit
```

インストール時にスコープを選択する:

| スコープ | 意味 | 推奨ケース |
|---|---|---|
| **user scope** | 自分の全プロジェクトで有効 | セキュリティ系（security-baseline, protect-bash）はこれ |
| **project scope** | リポジトリの共同作業者全員に適用 | チームで統一したい場合 |
| **local scope** | 自分だけ、このリポジトリだけ | 試しに1プロジェクトで使いたい場合 |

### 方法 2: ローカル開発用

```bash
claude --plugin-dir /path/to/forge-devkit/plugins/security-baseline \
       --plugin-dir /path/to/forge-devkit/plugins/protect-bash \
       --plugin-dir /path/to/forge-devkit/plugins/go-linter \
       --plugin-dir /path/to/forge-devkit/plugins/frontend-linter
```

## permissions テンプレート

プラグインの仕様上、`settings.json` の permissions は自動配布できない。`templates/project-root/.claude/settings.json` にテンプレートを同梱している。

security-baseline プラグインはセッション開始時に `.claude/settings.json` の状態を自動チェックし、未設定の場合は `/setup-permissions` の実行を案内する。

手動で適用する場合:

```bash
cp -r templates/project-root/.claude /path/to/your-project/.claude
```

### テンプレートに含まれるもの

**deny ルール（60+ パターン）:**
- 環境変数: `.env`, `.env.*`
- SSH / 暗号鍵: `.pem`, `.key`, `.p12`, `.pfx`, `.keystore`, `id_rsa`, `id_ed25519`
- AWS: `.aws/credentials`, `.aws/config`
- GCP: `credentials.json`, `serviceAccountKey*.json`
- CloudFlare: `cloudflare.ini`, `wrangler.toml`, `.cloudflared/`
- ホスティング: `.vercel/`, `.netlify/`, `.firebaserc`, `.railway/`, `.supabase/`, `amplify/.config/`
- Neon / DB: `.neon`, `.pgpass`
- Terraform: `*.tfstate`, `*.tfvars`
- その他: `.npmrc`, `.pypirc`, `.docker/config.json`, `.kube/config`, `.netrc`

**allow ルール（最小権限）:**
- `go mod tidy`, `go build ./...`, `go vet ./...`, `go test` 系, `ls`

**enabledPlugins:**
- forge-devkit 4 プラグイン + 公式マーケットプレイスの推奨 14 プラグイン

### なぜプラグインとテンプレートが分かれているか

プラグインの hooks は Bash ツール経由のアクセスをブロックするが、Read / Edit / Write ツールの直接アクセスは `settings.json` の deny ルールでしかブロックできない。両方あって初めて完全な防御になる。

## ローカル開発・テスト

```bash
# 単体テスト
claude --plugin-dir ./plugins/protect-bash

# 全プラグインまとめて
claude --plugin-dir ./plugins/security-baseline \
       --plugin-dir ./plugins/protect-bash \
       --plugin-dir ./plugins/go-linter \
       --plugin-dir ./plugins/frontend-linter

# デバッグモード
claude --debug --plugin-dir ./plugins/protect-bash

# セッション中のリロード
/reload-plugins
```

## 前提条件

- [jq](https://jqlang.github.io/jq/) — hook スクリプトが JSON パースに使用
- [golangci-lint](https://golangci-lint.run/) — go-linter 用（未インストールでもエラーにはならない）
- [oxlint](https://oxc.rs/docs/guide/usage/linter.html) or [ESLint](https://eslint.org/) — frontend-linter 用（未検出時はスキップ）

## ライセンス

MIT
