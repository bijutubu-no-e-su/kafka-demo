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

1. サービスをバックグラウンドで起動

```bash
docker compose up -d
```

2. サービス状況確認

```bash
docker compose ps
```

3. ksqlDB

- ksqlDB サーバーは http://localhost:8088 でアクセス可能です（ksqlDB UI を利用する場合）。

4. Debezium Connect REST API

- コネクタの登録は http://localhost:8083 に対して行います（POST で JSON を送る）。

5. UI

- ブラウザで http://localhost:3000 を開くと、SSE を使ったデモ UI を確認できます。

設定・注意点

- `docker-compose.yml` の重要な挙動:
  - Kafka は compose 内では `kafka:9092`、ホスト向けには `localhost:29092`（compose でのポートマッピング）として公開されています。
  - Postgres は `debezium/postgres` イメージを使用しており、logical replication を有効にするための設定や初期スクリプト（`init/`）が組み込まれています。
  - Debezium Connect は Postgres を `pg:5432`（サービス名 `postgres`、container_name `pg`）で参照する想定です。
  - UI サービスは compose ネットワーク内で `kafka:9092` に接続するように設定されています。

Debezium / Postgres のよくある落とし穴

- トピック名: Debezium の Postgres コネクタはトピック命名に `database.server.name` を使います（`topic.prefix` ではありません）。デフォルトでは `${database.server.name}.public.a_panel` のような名前になります。
- Postgres 側設定: logical replication を使うために `wal_level=logical`、十分な `max_replication_slots`、`max_wal_senders` が必要です。`debezium/postgres` イメージはデフォルトで整備されていますが、通常の Postgres イメージを使う場合は注意してください。
- コネクタ用ユーザー: Debezium が使う Postgres ユーザーにレプリケーション権限が必要です。

ksqlDB のポイント

- `ksql/statements.sql` は `pg.public.a_panel` を元に `A_STREAM` を作り、`B_STREAM`/`C_STREAM`/`D_STREAM` を派生させます。
- ソーストピックが存在し、JSON フォーマット（または ksqlDB 側で期待されるフォーマット）になっていることを確認してください。Avro などを使う場合は ksqlDB の `VALUE_FORMAT` を合わせる必要があります。

UI のポイント

- `ui/server.js` は `TOPICS` 環境変数で列挙されたトピックを購読します。デフォルトは `pg.public.a_panel,B_STREAM,C_STREAM,D_STREAM` です。
- `fromBeginning: true` で購読しているため、初回起動時に既存メッセージをすべて再生します。

トラブルシューティングチェックリスト

- Debezium がトピックを作らない場合:

  - Connect コンテナのログを確認: `docker compose logs -f connect`
  - コネクタ設定が正しいか確認（`http://localhost:8083/connectors` に対する POST ボディ）
  - Connect コンテナから Postgres に `pg` で到達できるか確認

- UI が Kafka に接続できない場合:

  - Kafka ブローカーが稼働しているか確認: `docker compose logs kafka`、またはコンテナ内で `kafka-topics --bootstrap-server kafka:9092 --list` を実行
  - UI を compose 外で動かす場合はブローカー接続先を `localhost:29092` に変更する必要があります。

- トピック名が期待どおりでない場合:
  - コネクタ設定内の `database.server.name` と、もし使っていれば RegexRouter 等の transform 設定を確認してください。正規表現内のドットは `\.` のようにエスケープが必要です。

コネクタ設定の例（最小限の重要項目）

```json
{
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
}
```

次にやれること

- コネクタの JSON と登録用の curl コマンドを README に追加して自動化する
- こちらで `docker compose up` を実行して動作確認とログ解析を行う（実行許可が必要）

ライセンス

教育目的のサンプルコードとして提供します。
