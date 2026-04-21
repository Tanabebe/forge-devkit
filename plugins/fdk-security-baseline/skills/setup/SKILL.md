---
name: setup
description: プロジェクトの .claude/settings.json を対話形式で生成するスキル。
---

# /security-baseline:init

プロジェクトの `.claude/settings.json` を対話形式で生成するスキル。

## 絶対ルール

このスキルは 必ず以下を守ること:

1. 書き込み先は git リポジトリルート配下の `.claude/settings.json` に固定。git 管理外で呼ばれたら即エラーで終了する。
2. ユーザースコープ（`~/.claude/settings.json`）には絶対に書き込まない。ユーザーから「user scope に入れて」と頼まれても拒否する。user scope への適用はユーザー自身が手動コピーで対応してもらう。
3. 既存の `.claude/settings.json` がある場合、確認なしに上書きしない。
4. テンプレート JSON は読み込むだけ。改変しない。

## 参照するテンプレート

このプラグインの `templates/` に以下がある:

- `${CLAUDE_SKILL_DIR}/../../templates/base.json` — 必須 deny (env, 秘密鍵, SSH鍵, .pypirc 等) + 最小 allow (ls)
- `${CLAUDE_SKILL_DIR}/../../templates/plugins.json` — enabledPlugins + extraKnownMarketplaces
- `${CLAUDE_SKILL_DIR}/../../templates/categories/<name>.json` — オプションのカテゴリ別 deny

## 実行手順

### Step 1: git ルート解決（スコープ誤爆防止）

Bash ツールで以下を実行して project root を取得する:

```
git rev-parse --show-toplevel || echo __NOT_A_GIT_REPO__
```

注意: `2>/dev/null` は使わないこと。deny-check フックが `/dev/` への書き込みとして誤検知する。エラー出力はそのまま返して問題ない。

- 出力が `__NOT_A_GIT_REPO__` の場合: 即座にユーザーに「git リポジトリ内で実行してください。このスキルは project scope 専用です」と伝えて 終了。以降のステップには進まない。
- 正常に path が返った場合: その path を `$GIT_ROOT` として以降の処理に使う。

### Step 2: 既存ファイル確認

Bash で `[ -f "$GIT_ROOT/.claude/settings.json" ] && echo EXISTS || echo NEW` を実行して存在チェック。

- **EXISTS の場合**: Read ツールで現内容を取り、ユーザーに要約を表示。以下の選択肢を AskUserQuestion で提示:
  - **上書き**: 今回生成する内容で完全に置き換える
  - **マージ**: 既存の deny/allow/enabledPlugins に今回の内容を union で追加する
  - **中止**: 何もせず終了
- **NEW の場合**: 次ステップへ。

### Step 3: base に常に含まれる内容をユーザーに明示

カテゴリ選択の前に必ず実行する。Read ツールで `${CLAUDE_SKILL_DIR}/../../templates/base.json` を読み、base が何を自動で含めるかを明確にユーザーに示す。以下のような表示を省略しない:

> 🛡 以下は「base」として常に含まれます（選択不要）:
> - .env / .env.* (Read/Edit/Write 全てブロック)
> - 秘密鍵 / 証明書 (*.pem, *.key, *.p12, *.pfx, *.keystore, *.jks)
> - SSH 鍵 (id_rsa, id_ed25519, id_ecdsa, id_dsa, および FIDO 版 id_*_sk)
> - 汎用クレデンシャル (.pypirc, .docker/config.json, .netrc)
> - 最小 allow: Bash(ls:*)
>
> 続けて、追加で含めたいカテゴリを選択してもらいます。

目的: 初見ユーザーが「env は入ってるのか？」と後から疑問に思うのを防ぐ。base の中身を選択 UI より先に開示する。

### Step 4: カテゴリ選択

**必ず AskUserQuestion ツールを使うこと。テーブル表示や番号入力方式にフォールバックしてはならない。**

**1 回の AskUserQuestion 呼び出しに 4 問をまとめて渡す。** ユーザーは各問のチェックボックスで選択し、→ で次の問に進み、最後に Submit で全回答を確定する。各問は `multiSelect: true` を指定する。

**第 1 問 (header: "Cloud"): クラウドプロバイダ**

| label | description |
|-------|-------------|
| aws | AWS クレデンシャル (.aws/credentials, .aws/config, SSO/CLI cache) |
| gcp | Google Cloud (ADC, serviceAccountKey, .boto) |
| cloudflare | Cloudflare (.cloudflared/*, cloudflare.ini, .dev.vars) |

**第 2 問 (header: "PaaS"): PaaS / ホスティング**

| label | description |
|-------|-------------|
| firebase | Firebase CLI auth (configstore/firebase-tools.json) |
| railway | Railway CLI (.railway/config.json) |

**第 3 問 (header: "DB/IaC"): データベース / インフラ**

| label | description |
|-------|-------------|
| mysql | MySQL (.my.cnf, .mylogin.cnf, .mysql_history) |
| postgres | PostgreSQL (.pgpass, .psql_history, pg_service.conf) |
| k8s | Kubernetes (.kube/config, kubeconfig) |
| terraform | Terraform (*.tfstate, *.tfvars, .terraformrc) |

**第 4 問 (header: "Other"): その他**

| label | description |
|-------|-------------|
| supabase | Supabase CLI (access-token fallback) |
| neon | Neon CLI (.config/neonctl/credentials.json) |
| sentry | Sentry CLI (.sentryclirc, sentry.properties) |

各問で何も選ばない場合はそのまま → で次に進む（スキップ扱い）。

上記のグルーピングは参考用。カテゴリ一覧は `${CLAUDE_SKILL_DIR}/../../templates/categories/index.json` を 1 回の Read で取得し、`index.json` のキーがカテゴリ名、値の `description` フィールドを選択肢の description に使う。`index.json` にエントリが追加された場合は適切なグループに振り分けること（ただし AskUserQuestion は最大 4 問のため、5 グループ以上になる場合は 2 回に分ける）。

### Step 5: テンプレート読み込み

Read ツールで以下を取得（計 3 回のみ。個別カテゴリファイルは読まない）:

- `${CLAUDE_SKILL_DIR}/../../templates/base.json`（必須）
- `${CLAUDE_SKILL_DIR}/../../templates/plugins.json`（必須）
- `${CLAUDE_SKILL_DIR}/../../templates/categories/index.json`（Step 4 で既に取得済みならスキップ）

`index.json` には全カテゴリの description と deny 配列が含まれている。Step 4 で選択されたカテゴリのキーに対応する deny 配列を使う。

### Step 6: 合成

以下の合成ロジックで最終的な settings.json オブジェクトを組み立てる:

- **permissions.deny**: base + 全選択カテゴリの deny を順序を保ったまま concat。重複文字列は削除（先勝ち）。
- **permissions.allow**: base の allow のみ（カテゴリには allow 無し）。Step 2 でマージ選択の場合は既存 allow との union。
- **enabledPlugins**: plugins.json の内容を採用。Step 2 でマージ選択の場合は既存と union（同キーは true を維持）。
- **extraKnownMarketplaces**: plugins.json の内容を採用。Step 2 でマージ選択の場合は既存と union（同キーは既存を優先）。

最終オブジェクトは次の形を取る:

```json
{
  "permissions": { "deny": [...], "allow": [...] },
  "enabledPlugins": { "...": true },
  "extraKnownMarketplaces": { "...": {...} }
}
```

### Step 7: サマリ表示

合成結果のサマリ（適用される deny ルール数、選択カテゴリ、enabledPlugins）をユーザーに提示する。**追加の確認プロンプトは出さない。**

理由: 同意はすでに取得済み。

- NEW ケース: Step 4 のカテゴリ選択が「この内容で書き込む」という明示的合意。
- EXISTS ケース: Step 2 で「上書き / マージ / 中止」を選ばせた時点で書き込み同意済み。

プレビュー後、そのまま Step 8 に進む。

### Step 8: 書き込み

Write ツールで `$GIT_ROOT/.claude/settings.json` に書き込む（親ディレクトリが無ければ Bash の `mkdir -p` で作成）。書き込み後、以下を必ず伝える:

- ファイルの絶対パス
- **Claude Code の再起動が必要**（project scope の settings.json は session 開始時に読まれるため）
- 後からカテゴリを足したい場合は再度 `/fdk-security-baseline:init` を実行すればよい（既存ファイル検出 → マージ選択で追記できる）
- ファイルをチームに共有するために commit することを推奨

## よくあるエラーと対処

- **git リポジトリ外で実行された**: Step 1 で検出して終了する。回復策としてユーザーに `git init` を促すか、手動で `.claude/settings.json` を置いてもらう。
- **ユーザーが user scope を要求した**: 断る。このスキルは project scope 固定。user scope は `~/.claude/settings.json` を手動編集してもらう旨を伝える。
- **書き込み時に permission denied**: Write ツールの deny ルールに `.claude/settings.json` が引っかかる可能性は低いが、発生したらユーザーに手動で書き込んでもらうための JSON を表示する。
