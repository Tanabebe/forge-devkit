# セキュリティベースライン

## 機密ファイルへのアクセス禁止
以下のファイルは Read / Edit / Write のいずれも禁止:
- `.env`, `.env.*`（`.env.local`, `.env.production` 等すべて）
- `credentials.json`, `serviceAccountKey.json`
- 秘密鍵ファイル（`.pem`, `.key`, `.p12`, `.pfx`）
- SSH 鍵（`id_rsa`, `id_ed25519`）
- パッケージレジストリ認証（`.npmrc`, `.pypirc`）

## 機密ファイルの検索禁止
以下のファイルは Glob / Grep による検索も禁止:
- 上記の機密ファイルすべて
- クラウド認証情報（`.aws/`, `.boto`, `cloudflare.ini`, `wrangler.toml`）
- DB 認証（`.pgpass`, `.neon`）
- インフラ設定（`.tfvars`, `.tfstate`, `.kube/config`, `.docker/config.json`）
- ホスティングサービス（`.vercel/`, `.netlify/`, `.firebaserc`, `.railway/`, `.supabase/`, `amplify/.config/`）

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
