# セキュリティベースライン

## 機密ファイルへのアクセス禁止
以下のファイルは Read / Edit / Write のいずれも禁止:
- `.env`, `.env.*`（`.env.local`, `.env.production` 等すべて）
- `serviceAccountKey.json`, `application_default_credentials.json`
- 秘密鍵ファイル（`.pem`, `.key`, `.p12`, `.pfx`, `.keystore`, `.jks`）
- SSH 鍵（`id_rsa`, `id_ed25519`, `id_ecdsa`, `id_dsa`, FIDO 版 `id_*_sk`）
- パッケージレジストリ認証（`.npmrc`, `.pypirc`）
- Cloudflare 開発用シークレット（`.dev.vars`, `.dev.vars.*`）

## 機密ファイルの検索禁止
以下のファイルは Glob / Grep による検索も禁止:
- 上記の機密ファイルすべて
- クラウド認証情報（`.aws/credentials`, `.aws/config`, `.aws/sso/cache`, `.boto`, `cloudflare.ini`）
- DB 認証（`.pgpass`, `.my.cnf`, `.mylogin.cnf`）
- インフラ設定（`.tfvars`, `.tfstate`, `.terraformrc`, `.kube/config`, `.docker/config.json`）
- CLI auth ファイル（`.railway/config`, `.supabase/access-token`, `.config/neonctl/credentials`, `.config/configstore/firebase-tools`, `.config/gcloud/application_default_credentials`）

## 破壊的操作の禁止
以下のコマンドは Bash で実行禁止:
- `rm -rf`, `rm -r`, `rm -f` — ファイル/ディレクトリの強制削除
- `dd`, `mkfs`, `fdisk` — ディスク操作
- `chmod`, `chown` — 権限/所有権の変更
- `kill -9`, `killall` — プロセスの強制終了
- `sudo` — 権限昇格
- `git push --force`, `git reset --hard`, `git clean -f` — Git の破壊的操作
- `DROP TABLE/DATABASE`, `TRUNCATE` — データベースの破壊的操作

## 意図
これらの制限は事故防止のためのガードレール。
正当な理由がある場合はユーザーが手動で実行すべき操作であり、AI アシスタントが自動実行すべきではない。
