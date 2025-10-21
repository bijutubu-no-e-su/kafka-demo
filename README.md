# kafka-demo

このリポジトリは、PostgreSQL の変更（CDC）を Debezium を使って Apache Kafka に流し、ksqlDB でストリーム処理を行い、React + SSE（Server-Sent Events）で結果を可視化する小さなデモです。

目次

- `docker-compose.yml` - Kafka（Confluent）、Debezium Postgres、Debezium Connect、ksqlDB、UI をまとめて立ち上げる定義
- `init/01_schema.sql` - Postgres の初期スキーマとサンプルデータ
- `ksql/statements.sql` - Debezium が作成するトピックを元に ksqlDB のストリームを作る例
- `ui/` - kafkajs を使って Kafka トピックを購読し、SSE でブラウザに配信する React + Express の UI

概要

- Postgres（`debezium/postgres` イメージ）には `a_panel` テーブルがあり、初期データが 1 行挿入されています。
- Debezium Connect が Postgres の変更を検知して `pg.public.a_panel` のようなトピックにイベントを送ります。
- ksqlDB は `pg.public.a_panel` を読み取り、`B_STREAM`、`C_STREAM`、`D_STREAM` といった派生ストリームを作成して色の変換ロジックを適用します。
- UI（Express + kafkajs）はこれらのトピックを購読し、ブラウザへ SSE で状態の更新を送ります。

起動方法（docker-compose を利用）

# kafka-demo

このリポジトリは、PostgreSQL の変更（CDC）を Debezium → Kafka → ksqlDB のパイプラインで流し、
最終的に React + SSE（Server-Sent Events）でブラウザにリアルタイム表示するデモです。

README を最新化しました。以下は現在の構成、起動手順、重要ファイル、デバッグのヒントです。

## 構成（主なコンポーネント）

- `kafka` : Confluent Kafka ブローカー（compose 内は `kafka:9092`、ホスト向けに `localhost:29092` を公開）
- `postgres` (`debezium/postgres`) : デモ用の Postgres（logical replication 対応）
- `connect` : Debezium Connect（Postgres の変更を Kafka トピックに送信）
- `ksqldb` : ksqlDB サーバ（`./ksql/statements.sql` を参照してストリーム／テーブルを作る想定）
- `db-writer` : Kafka の B/C/D 系トピックを受けて Postgres に upsert する（データ循環の例）
- `ui` : React + Express（`kafkajs` でトピックを購読して SSE でブラウザに配信）
- `connect-init` : 初期化用のコンテナ（connect にコネクタを登録するためのスクリプトを実行）

## 重要ファイル

- `docker-compose.yml` : 全サービスの定義（トピック設定、環境変数、ボリューム等）
- `init/01_schema.sql` : Postgres の初期スキーマとサンプルデータ（例: `a_panel` テーブル）
- `ksql/statements.sql` : ksqlDB のサンプル定義（A_SRC / A_REKEY / B_TBL / C_TBL / D_TBL）
- `connect-init/register.sh` : Debezium コネクタを自動登録するスクリプト（`connect-init` コンテナから実行）
- `ui/` : UI のソースコード（React + Express）
  - `ui/server.js` : Kafka を購読し SSE にブロードキャストするサーバ
  - `ui/src/` : React アプリ（`App.jsx`, `main.jsx`, `styles.css`）

## 起動手順（ローカル、docker-compose 利用）

1. コンテナ群をバックグラウンドで起動

```bash
docker compose up -d
```

2. サービスの状態を確認

```bash
docker compose ps
```

3. 初期化スクリプトの実行確認

- `connect-init` コンテナは `connect` が起動した後に `connect` へコネクタを登録するためのスクリプトを実行します。`docker compose logs connect-init` で実行状況を確認してください。

4. ksqlDB

- ksqlDB サーバは `http://localhost:8088` でアクセス可能です（ksqlDB UI や REST API を使用して `ksql/statements.sql` を適用できます）。

5. UI

- ブラウザで `http://localhost:3000` を開くと UI が表示されます（Compose 設定では UI コンテナが `3000` ポートでリッスン）。

### UI をローカルで開発モードで動かす

もしソースを直接編集しながら開発する場合:

```bash
cd ui
npm install
npm run dev    # Vite の dev サーバを起動 (ホットリロードあり)
```

または本番ビルドを作成して server.js で配信する場合:

```bash
cd ui
npm install
npm run build
npm start      # server.js が dist を配信して http://localhost:3000 を提供
```

## 現在のトピック設計（重要）

- デフォルトで UI は次のトピックを購読するように設定されています（`ui/server.js` の `TOPICS` 環境変数）:
  - `pg.public.a_panel` (Debezium が生成するトピック)
  - `b_panel_topic`, `c_panel_topic`, `d_panel_topic` (ksqlDB / TABLE 出力や中間トピックの例)

※ 環境変数 `TOPICS` を変更すれば購読するトピックをカスタマイズできます。Compose では `TOPICS` が `pg.public.a_panel,b_panel_topic,c_panel_topic,d_panel_topic` に設定されています。

## ksqlDB と statements.sql のポイント

- `ksql/statements.sql` は Debezium の出力（JSON）を読み、内部で再キー化 (A_REKEY) した上で TABLE を作り、色変換（black → pink → grey → white）を適用します。
- ksqlDB のバージョンや環境によっては JSON の unwrap（payload.after の展開）が必要です。`ksql/statements.sql` の注釈を参照して、Debezium の出力形式に合わせてください。

## db-writer の役割

- `db-writer` サービスは Kafka 上の `b_panel_topic`, `c_panel_topic`, `d_panel_topic` を監視し、Postgres に対して upsert（挿入/更新）を行う小さなワーカーです。これによりデータの往復パターン（Postgres → Kafka → ksqlDB → Kafka → Postgres）を実演できます。

## よくある問題と確認コマンド

- Connect がコネクタを作成しているか確認:

```bash
docker compose logs -f connect
```

- Kafka のトピック一覧確認（コンテナ内で実行）:

```bash
docker compose exec kafka kafka-topics --bootstrap-server kafka:9092 --list
```

- ksqlDB のログや UI でステートメントの適用状況を確認

- UI のログ確認:

```bash
docker compose logs -f ui
```

- ブラウザの DevTools で `/sse` のイベントストリームを確認（Network タブ）

## トラブルシューティングのヒント

- UI に色が反映されない場合:

  - サーバが送っている SSE メッセージの payload を確認（ブラウザの Network → `/sse` を開く）。
  - サーバ側ログ（`docker compose logs ui`）で JSON パースや broadcast エラーが出ていないか確認。
  - 受け取った color 値が CSS として有効（例: `black`, `#000000` 等）か確認。

- Kafka にメッセージが到達していない場合:
  - Connect のログ、Postgres 側の WAL / replication 設定を確認。
  - Debezium のコネクタ設定（`database.server.name`, `table.include.list` 等）を見直す。

## コネクタ登録の例（curl）

`connect-init/register.sh` が自動で登録する想定ですが、手動で登録したい場合の最小例:

```bash
curl -X POST -H "Content-Type: application/json" \
  --data '{
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "database.hostname": "pg",
    "database.port": "5432",
    "database.user": "postgres",
    "database.password": "postgres",
    "database.dbname": "demo",
    "database.server.name": "pg",
    "plugin.name": "pgoutput",
    "publication.autocreate.mode": "filtered",
    "schema.include.list": "public",
    "table.include.list": "public.a_panel"
  }' \
  http://localhost:8083/connectors
```

## 追加の推奨作業

- ksqlDB の `statements.sql` は環境に合わせて JSON パスや unwrap の有無を調整してください。実際の Kafka メッセージ（`pg.public.a_panel`）のサンプルを確認すると調整が容易になります。
- UI に受信メッセージのデバッグ表示（raw JSON ビュー）を一時的に追加すると問題の切り分けが速くなります。

## ライセンス

教育目的のサンプルコードとして提供します。

## 起動

起動: docker compose down -v && docker compose up -d

ksql 定義投入:
jq -n --rawfile sql ksql/statements.sql '{ksql:$sql,streamsProperties:{}}' | curl -sS -X POST http://localhost:8088/ksql -H 'Content-Type: application/vnd.ksql.v1+json; charset=utf-8' -d @-

動作確認: A を UPDATE → b_panel_topic / c_panel_topic / d_panel_topic を確認
