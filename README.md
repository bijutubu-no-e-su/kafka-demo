# Kafka Demo - リアルタイムデータパイプラインシステム

これは Kafka、Debezium、ksqlDB、PostgreSQL を使用したリアルタイムデータ変換パイプラインのデモシステムです。データベースの変更を Kafka 経由でリアルタイムに監視し、段階的なデータ変換を行いながら、Web UI で結果を可視化できます。

## システム概要

![システム図]

```text
PostgreSQL (4つのテーブル: a_panel → b_panel → c_panel → d_panel)
    ↓ (Debezium CDC)
Apache Kafka (データストリーム)
    ↓ (ksqlDB Stream Processing)
段階的な色変換処理
    ↓ (Kafka Connect Sink)
PostgreSQL への書き戻し
    ↓ (REST API)
React ベースの Web UI
```

### データフロー

1. **a_panel** テーブルのデータが更新される
2. **Debezium** が変更を検知し、Kafka トピックに送信
3. **ksqlDB** がストリーム処理で色変換ロジックを実行
4. **db-writer** サービスが変換結果を次のテーブルに書き込み
5. **Web UI** が最新の状態をリアルタイム表示

### 色変換ルール

- A → B: `blue` → `yellow`, その他の色も変換
- B → C: `yellow` → `red`, その他の色も変換
- C → D: `red` → `green`, その他の色も変換

## システム構成

### コアサービス

| サービス    | 説明                                     | ポート |
| ----------- | ---------------------------------------- | ------ |
| **kafka**   | Apache Kafka ブローカー（KRaft モード）  | 29092  |
| **pg**      | PostgreSQL データベース（Debezium 対応） | 5432   |
| **connect** | Debezium Kafka Connect                   | 8083   |
| **ksqldb**  | ksqlDB ストリーム処理エンジン            | 8088   |

### アプリケーションサービス

| サービス         | 説明                            | ポート |
| ---------------- | ------------------------------- | ------ |
| **web**          | REST API サーバー（Express.js） | 8080   |
| **ui**           | フロントエンド（React + Vite）  | 5173   |
| **db-writer-ab** | A→B パネル変換                  | -      |
| **db-writer-bc** | B→C パネル変換                  | -      |
| **db-writer-cd** | C→D パネル変換                  | -      |

### ユーティリティ

| サービス         | 説明                      |
| ---------------- | ------------------------- |
| **connect-init** | Debezium コネクタ自動登録 |

## 前提条件

- Docker Desktop または Docker Engine + Docker Compose
- 最低 8GB の RAM 推奨
- ポート 5173, 8080, 8083, 8088, 29092, 5432 が使用可能であること

## クイックスタート

### 1. システム起動

```bash
# 全サービス起動
docker compose up -d

# ログ確認
docker compose logs -f
```

### 2. Web UI へアクセス

ブラウザで <http://localhost:5173> を開く

4 つのパネル（a_panel, b_panel, c_panel, d_panel）の現在の色が表示されます。

### 3. データ変更をテスト

PostgreSQL に直接接続してデータを変更：

```bash
# PostgreSQL シェルに接続
docker compose exec -it pg psql -U postgres -d demo

# a_panel の色を変更
UPDATE a_panel SET color = 'blue' WHERE id = 1;

# 結果確認
SELECT 'a_panel' as table_name, color FROM a_panel WHERE id = 1
UNION ALL
SELECT 'b_panel', color FROM b_panel WHERE id = 1
UNION ALL
SELECT 'c_panel', color FROM c_panel WHERE id = 1
UNION ALL
SELECT 'd_panel', color FROM d_panel WHERE id = 1;
```

Web UI で色の変化がリアルタイムに反映されることを確認できます。

## 利用可能なタスク

VS Code のタスクまたは以下のコマンドでシステムを管理できます：

```bash
# システム起動
docker compose up -d

# システム停止
docker compose down

# Kafka ログ監視
docker compose logs -f kafka

# Connect ログ監視
docker compose logs -f connect

# PostgreSQL シェル
docker compose exec -it pg psql -U postgres -d demo
```

## トラブルシューティング

### ksqlDB 関連

ksqlDB のストリーム定義に問題がある場合：

```bash
# 現状確認
./ksql_check.sh

# 問題修正
./ksql_check_and_fix.sh

# 完全リセット
./ksql_reset_and_recreate.sh
```

### よくある問題

1. **コンテナが起動しない**

   - Docker リソース不足の可能性
   - ポート衝突の確認

2. **データが流れない**

   - Debezium コネクタの状態確認
   - ksqlDB ストリームの状態確認

3. **Web UI に接続できない**
   - `web` サービスの起動確認
   - API エンドポイント（<http://localhost:8080/api/panels>）の動作確認

## 開発・カスタマイズ

### 色変換ロジックの変更

1. **ksqlDB ストリーム**: `ksql/statements.sql`
2. **db-writer 変換マップ**: 各 `db-writer-*` の環境変数 `COLOR_MAP_JSON`

### UI のカスタマイズ

- フロントエンド: `ui/src/`
- API サーバー: `web/server.js`

### データベーススキーマ

- 初期化スクリプト: `init/01_schema.sql`
- 4 つのテーブル（a_panel, b_panel, c_panel, d_panel）
- 各テーブルに `updated_at` トリガーが設定済み

## API リファレンス

### REST API エンドポイント

```http
GET /api/panels
```

レスポンス例：

```json
{
  "a": { "id": 1, "color": "blue", "updated_at": "2024-01-01T00:00:00.000Z" },
  "b": { "id": 1, "color": "red", "updated_at": "2024-01-01T00:00:01.000Z" },
  "c": { "id": 1, "color": "green", "updated_at": "2024-01-01T00:00:02.000Z" },
  "d": { "id": 1, "color": "purple", "updated_at": "2024-01-01T00:00:03.000Z" }
}
```

## 技術スタック

- **データ基盤**: Apache Kafka (KRaft), PostgreSQL, Debezium, ksqlDB
- **バックエンド**: Node.js, Express.js
- **フロントエンド**: React, TypeScript, Vite
- **インフラ**: Docker, Docker Compose

## ライセンス

MIT License

---

このデモシステムは、リアルタイムデータパイプライン、Change Data Capture (CDC)、ストリーム処理の学習・検証に最適です。

## 詳細セットアップ

### 完全起動手順

```bash
# 1. 全サービス起動（データベース初期化含む）
docker compose down -v && docker compose up -d

# 2. 全サービスが起動するまで待機（約30秒）
docker compose logs -f

# 3. ksqlDB統計クエリを手動で投入（オプション）
# ksqlDBコンテナ内で直接実行する方法
docker compose exec ksqldb ksql http://localhost:8088
```

### ksqlDB 統計定義の投入

**方法 1: ksqlDB シェル経由（推奨）**

```bash
# ksqlDBシェルに接続
docker compose exec ksqldb ksql http://localhost:8088

# シェル内で以下を実行
SET 'auto.offset.reset' = 'earliest';

CREATE STREAM IF NOT EXISTS a_panel_events (id INT, color VARCHAR, updated_at BIGINT)
WITH (KAFKA_TOPIC = 'pg.public.a_panel', VALUE_FORMAT = 'JSON');

CREATE TABLE IF NOT EXISTS color_stats AS
SELECT color, COUNT(*) as total_changes
FROM a_panel_events GROUP BY color;
```

**方法 2: 最も確実な方法（推奨）**

```bash
# ksqlDBコンテナ内からファイルを直接実行
docker compose exec ksqldb bash -c "
cat << 'EOF' | ksql http://localhost:8088
SET 'auto.offset.reset' = 'earliest';

CREATE STREAM IF NOT EXISTS a_panel_events (id INT, color VARCHAR, updated_at BIGINT)
WITH (KAFKA_TOPIC = 'pg.public.a_panel', VALUE_FORMAT = 'JSON');

CREATE TABLE IF NOT EXISTS color_stats AS
SELECT color, COUNT(*) as total_changes
FROM a_panel_events GROUP BY color;

CREATE TABLE IF NOT EXISTS latest_updates AS
SELECT 'a_panel' as panel_name, LATEST_BY_OFFSET(color) as current_color
FROM a_panel_events GROUP BY 'a_panel';
EOF
"
```

**方法 3: jq 経由での投入（ネットワーク環境に依存）**

```bash
# 方法3-1: 完全なSQL文を一度に投入
cat ksql/statements.sql | jq -Rs '{ksql: ., streamsProperties: {}}' | \
curl -sS -X POST http://localhost:8088/ksql \
  -H 'Content-Type: application/vnd.ksql.v1+json; charset=utf-8' \
  -d @- | jq .

# 方法3-2: より安全な方法（改行処理込み）
jq -n --rawfile sql ksql/statements.sql \
  --argjson props '{}' \
  '{ksql: $sql, streamsProperties: $props}' | \
curl -sS -X POST http://localhost:8088/ksql \
  -H 'Content-Type: application/vnd.ksql.v1+json; charset=utf-8' \
  -d @- | jq .

# 方法3-3: コンテナ内からjq実行（プロキシ回避）
docker compose exec ksqldb bash -c "
echo 'SET \"auto.offset.reset\" = \"earliest\";

CREATE STREAM IF NOT EXISTS a_panel_events (id INT, color VARCHAR, updated_at BIGINT)
WITH (KAFKA_TOPIC = \"pg.public.a_panel\", VALUE_FORMAT = \"JSON\");

CREATE TABLE IF NOT EXISTS color_stats AS
SELECT color, COUNT(*) as total_changes
FROM a_panel_events GROUP BY color;' | \
jq -Rs '{ksql: ., streamsProperties: {}}' | \
curl -sS -X POST http://localhost:8088/ksql \
  -H 'Content-Type: application/vnd.ksql.v1+json; charset=utf-8' \
  -d @-
"
```

**方法 4: 手動でコピー&ペースト**

```bash
# 1. ksqlDBシェルに接続
docker compose exec ksqldb ksql http://localhost:8088

# 2. 以下のSQLを順番に実行
SET 'auto.offset.reset' = 'earliest';

CREATE STREAM IF NOT EXISTS a_panel_events (id INT, color VARCHAR, updated_at BIGINT)
WITH (KAFKA_TOPIC = 'pg.public.a_panel', VALUE_FORMAT = 'JSON');

CREATE TABLE IF NOT EXISTS color_stats AS
SELECT color, COUNT(*) as total_changes FROM a_panel_events GROUP BY color;
```

**方法 5: 個別ステートメント投入**

```bash
# SET文
curl -X POST http://localhost:8088/ksql \
  -H "Content-Type: application/vnd.ksql.v1+json" \
  -d '{"ksql": "SET '\''auto.offset.reset'\'' = '\''earliest'\'';"}'

# STREAM作成
curl -X POST http://localhost:8088/ksql \
  -H "Content-Type: application/vnd.ksql.v1+json" \
  -d '{"ksql": "CREATE STREAM IF NOT EXISTS a_panel_events (id INT, color VARCHAR, updated_at BIGINT) WITH (KAFKA_TOPIC = '\''pg.public.a_panel'\'', VALUE_FORMAT = '\''JSON'\'');"}'
```

### 動作確認

```bash
# PostgreSQLでa_panelを更新
docker compose exec pg psql -U postgres -d demo -c "UPDATE a_panel SET color = 'blue' WHERE id = 1;"

# 連鎖的な色変更を確認
docker compose exec pg psql -U postgres -d demo -c "
SELECT 'a_panel' as panel, color FROM a_panel WHERE id = 1
UNION ALL SELECT 'b_panel', color FROM b_panel WHERE id = 1
UNION ALL SELECT 'c_panel', color FROM c_panel WHERE id = 1
UNION ALL SELECT 'd_panel', color FROM d_panel WHERE id = 1;"

# Web UIで確認: http://localhost:5173
```

### トラブルシューティング

**ksqlDB クエリ失敗時:**

```bash
# ksqlDBログ確認
docker compose logs ksqldb

# 既存クエリ確認
docker compose exec ksqldb ksql http://localhost:8088 -e "SHOW STREAMS; SHOW TABLES;"
```
