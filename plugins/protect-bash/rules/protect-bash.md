# Bash コマンド保護ルール

## 概要
Bash ツール経由で実行されるコマンドを包括的に検査し、危険な操作をブロックする。

## 保護カテゴリ

### 1. 機密ファイルへの間接アクセス
cat, grep, head, tail, sed, awk, source 等で以下のファイルを読み取る操作を検出:
- `.env`, `.env.*` — 環境変数ファイル
- `credentials.json`, `serviceAccountKey*.json` — GCP 認証情報
- `.aws/credentials`, `.aws/config` — AWS 認証情報
- `cloudflare.ini`, `wrangler.toml` — CloudFlare 設定
- `.pgpass`, `.netrc` — データベース/ネットワーク認証
- `.npmrc`, `.pypirc` — パッケージレジストリ認証
- `.docker/config.json`, `.kube/config` — コンテナ/K8s 認証
- `*.tfvars`, `*.tfstate` — Terraform 変数/ステート

find, locate, fd による機密ファイルの検索もブロック。

### 2. ファイル/ディレクトリの破壊的操作
- `rm -rf`, `rm -f` 等の強制削除
- `dd`, `mkfs`, `fdisk` 等のディスク操作
- `chmod`, `chown` 等の権限変更
- `sudo` による権限昇格

### 3. Git の破壊的操作
- `git push --force`, `git push -f`
- `git reset --hard`, `git clean -f`
- `git branch -D`（強制削除）
- `git stash drop/clear`

### 4. IaC（Infrastructure as Code）の破壊的操作
- `terraform destroy`, `terraform apply`, `terraform state rm`
- `tofu destroy`, `tofu apply`
- `terragrunt destroy`, `terragrunt apply`
- `pulumi destroy`, `pulumi up`

### 5. クラウド CLI の危険な操作
- **AWS**: `aws ... delete-*`, `aws s3 rm`, `aws iam`
- **GCP**: `gcloud ... delete`, `gcloud iam`, `gcloud projects delete`
- **CloudFlare**: `wrangler delete`, `wrangler d1 delete`
- **Vercel**: `vercel remove`, `vercel env rm`
- **Neon**: `neonctl ... delete/drop`
- **Docker**: `docker system prune`, `docker volume rm`
- **Kubernetes**: `kubectl delete`, `kubectl drain`
- **SQL**: `DROP TABLE/DATABASE`, `TRUNCATE`, `DELETE FROM`

### 6. パッケージマネージャの危険な操作
- `npm -g` / `npm --global`（グローバルインストール）
- `curl ... | sh/bash`（リモートスクリプト実行）

## 意図
AI アシスタントが自動実行すべきでない操作を網羅的にブロックする。
正当な理由がある場合はユーザーが手動で実行すべき。
