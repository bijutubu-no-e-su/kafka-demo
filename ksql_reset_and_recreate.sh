#!/bin/bash
set -e

echo "🧹 Step1: 既存の定義とトピックを全削除..."
cat <<'EOF' | curl -s -X POST http://localhost:8088/ksql \
  -H "Content-Type: application/vnd.ksql.v1+json; charset=utf-8" \
  -d @-
{
  "ksql": "
    DROP TABLE IF EXISTS D_TBL DELETE TOPIC;
    DROP TABLE IF EXISTS C_TBL DELETE TOPIC;
    DROP TABLE IF EXISTS B_TBL DELETE TOPIC;
    DROP STREAM IF EXISTS D_STREAM DELETE TOPIC;
    DROP STREAM IF EXISTS C_STREAM DELETE TOPIC;
    DROP STREAM IF EXISTS B_STREAM DELETE TOPIC;
    DROP STREAM IF EXISTS A_REKEY DELETE TOPIC;
    DROP STREAM IF EXISTS A_SRC DELETE TOPIC;
  "
}
EOF
echo "✅ 全削除完了"

echo
echo "🪄 Step2: A_SRC を最新オフセットで再作成 (古いレコードをスキップ)"
cat <<'EOF' | curl -s -X POST http://localhost:8088/ksql \
  -H "Content-Type: application/vnd.ksql.v1+json; charset=utf-8" \
  -d @-
{
  "ksql": "
    SET 'auto.offset.reset'='latest';
    CREATE STREAM A_SRC (
      id INT,
      color STRING,
      updated_at BIGINT,
      __op STRING,
      __ts_ms BIGINT
    ) WITH (
      KAFKA_TOPIC='pg.public.a_panel',
      VALUE_FORMAT='JSON'
    );
  "
}
EOF
echo "✅ A_SRC 再作成完了"

echo
echo "🔑 Step3: id をキーとして再パーティション (A_REKEY)"
cat <<'EOF' | curl -s -X POST http://localhost:8088/ksql \
  -H "Content-Type: application/vnd.ksql.v1+json; charset=utf-8" \
  -d @-
{
  "ksql": "
    CREATE STREAM A_REKEY
    WITH (KAFKA_TOPIC='a_rekey_topic', KEY_FORMAT='JSON', VALUE_FORMAT='JSON')
    AS SELECT id, color, updated_at, __op, __ts_ms
    FROM A_SRC
    PARTITION BY id
    EMIT CHANGES;
  "
}
EOF
echo "✅ A_REKEY 作成完了"

echo
echo "🎨 Step4: 連鎖テーブル B→C→D を再作成"
cat <<'EOF' | curl -s -X POST http://localhost:8088/ksql \
  -H "Content-Type: application/vnd.ksql.v1+json; charset=utf-8" \
  -d @-
{
  "ksql": "
    CREATE TABLE B_TBL
    WITH (KAFKA_TOPIC='b_panel_topic', KEY_FORMAT='JSON', VALUE_FORMAT='JSON')
    AS SELECT id,
             CASE WHEN LCASE(color)='black' THEN 'pink' ELSE color END AS color
       FROM A_REKEY
       GROUP BY id
       EMIT CHANGES;
  "
}
EOF

cat <<'EOF' | curl -s -X POST http://localhost:8088/ksql \
  -H "Content-Type: application/vnd.ksql.v1+json; charset=utf-8" \
  -d @-
{
  "ksql": "
    CREATE TABLE C_TBL
    WITH (KAFKA_TOPIC='c_panel_topic', KEY_FORMAT='JSON', VALUE_FORMAT='JSON')
    AS SELECT id,
             CASE WHEN LCASE(color)='pink' THEN 'grey' ELSE color END AS color
       FROM B_TBL
       EMIT CHANGES;
  "
}
EOF

cat <<'EOF' | curl -s -X POST http://localhost:8088/ksql \
  -H "Content-Type: application/vnd.ksql.v1+json; charset=utf-8" \
  -d @-
{
  "ksql": "
    CREATE TABLE D_TBL
    WITH (KAFKA_TOPIC='d_panel_topic', KEY_FORMAT='JSON', VALUE_FORMAT='JSON')
    AS SELECT id,
             CASE WHEN LCASE(color)='grey' THEN 'white' ELSE color END AS color
       FROM C_TBL
       EMIT CHANGES;
  "
}
EOF
echo "✅ B/C/D 作成完了"

echo
echo "🔍 Step5: 確認クエリ"
cat <<'EOF' | curl -s -X POST http://localhost:8088/ksql \
  -H "Content-Type: application/vnd.ksql.v1+json; charset=utf-8" \
  -d @-
{
  "ksql": "SHOW STREAMS; SHOW TABLES; SHOW TOPICS;"
}
EOF

echo
echo "🎯 Step6: A を black に更新して動作テスト"
docker exec -it pg psql -U postgres -d demo -c \
"UPDATE public.a_panel SET color='black', updated_at=now() WHERE id=1;"

echo
echo "📡 Step7: B/C/D トピック確認 (5秒ずつ)"
docker exec -it kafka bash -lc "kafka-console-consumer --bootstrap-server kafka:9092 --topic b_panel_topic --from-beginning --timeout-ms 5000"
docker exec -it kafka bash -lc "kafka-console-consumer --bootstrap-server kafka:9092 --topic c_panel_topic --from-beginning --timeout-ms 5000"
docker exec -it kafka bash -lc "kafka-console-consumer --bootstrap-server kafka:9092 --topic d_panel_topic --from-beginning --timeout-ms 5000"

echo
echo "✅ All Done.  A→B→C→D の連鎖が出ていれば成功！"
