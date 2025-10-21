#!/bin/bash
set -euo pipefail

KSQL=http://localhost:8088
BS=kafka:9092

echo "🔎 1) ksqlDB オブジェクト/トピックの現状確認..."
cat <<'EOF' | curl -s -X POST $KSQL/ksql \
  -H "Content-Type: application/vnd.ksql.v1+json; charset=utf-8" -d @- \
  | sed -n '1,200p'
{
  "ksql": "
    SHOW STREAMS;
    SHOW TABLES;
    SHOW TOPICS;
  "
}
EOF

echo
echo "🔎 2) Kafka 側トピック存在確認（管理API）..."
docker exec -it kafka bash -lc "kafka-topics --bootstrap-server $BS --list | sort | grep -E '(^|[^a-zA-Z])(b_panel_topic|c_panel_topic|d_panel_topic)($|[^a-zA-Z])' || true"

echo
echo "🔎 3) ksqlDB のエラー有無（直近ログ）..."
docker logs --tail=200 ksqldb | sed -n '1,200p' || true

echo
echo "🛠 4) B/C/D を“明示的パラメータ”付きで再作成（なければ作る／あれば再作成）..."
# すでに存在して失敗するのを避けるため、一旦 DROP（存在しなくてもOK）
for name in D_TBL C_TBL B_TBL; do
  cat <<EOF | curl -s -X POST $KSQL/ksql \
    -H "Content-Type: application/vnd.ksql.v1+json; charset=utf-8" -d @- >/dev/null || true
{
  "ksql": "DROP TABLE IF EXISTS $name DELETE TOPIC;"
}
EOF
done

# A_REKEY が無い（または怪しい）場合に備えて確認→無ければ作成
echo "🔎 A_REKEY の存在確認→無ければ作成"
HAS_A_REKEY=$(cat <<'EOF' | curl -s -X POST $KSQL/ksql \
  -H "Content-Type: application/vnd.ksql.v1+json; charset=utf-8" -d @- \
  | grep -c A_REKEY || true
{
  "ksql": "SHOW STREAMS;"
}
EOF
)
if [ "$HAS_A_REKEY" -eq 0 ]; then
  echo "➡ A_REKEY が無いので作成します"
  cat <<'EOF' | curl -s -X POST $KSQL/ksql \
    -H "Content-Type: application/vnd.ksql.v1+json; charset=utf-8" -d @- \
    | sed -n '1,120p'
{
  "ksql": "
    SET 'auto.offset.reset'='latest';
    CREATE STREAM IF NOT EXISTS A_SRC (
      id INT,
      color STRING,
      updated_at BIGINT,
      __op STRING,
      __ts_ms BIGINT
    ) WITH (
      KAFKA_TOPIC='pg.public.a_panel',
      VALUE_FORMAT='JSON'
    );

    CREATE STREAM A_REKEY
    WITH (KAFKA_TOPIC='a_rekey_topic', PARTITIONS=1, REPLICAS=1, KEY_FORMAT='JSON', VALUE_FORMAT='JSON')
    AS SELECT id, color, updated_at, __op, __ts_ms
    FROM A_SRC
    PARTITION BY id
    EMIT CHANGES;
  "
}
EOF
else
  echo "✅ A_REKEY は存在します"
fi

echo
echo "➡ B_TBL / C_TBL / D_TBL を CTAS（トピック名明示・PARTITIONS/REPLICAS 明示）で作成"
cat <<'EOF' | curl -s -X POST $KSQL/ksql \
  -H "Content-Type: application/vnd.ksql.v1+json; charset=utf-8" -d @- \
  | sed -n '1,200p'
{
  "ksql": "
    CREATE TABLE B_TBL
    WITH (KAFKA_TOPIC='b_panel_topic', PARTITIONS=1, REPLICAS=1, KEY_FORMAT='JSON', VALUE_FORMAT='JSON')
    AS SELECT id,
             CASE WHEN LCASE(color)='black' THEN 'pink' ELSE color END AS color
       FROM A_REKEY
       GROUP BY id
       EMIT CHANGES;

    CREATE TABLE C_TBL
    WITH (KAFKA_TOPIC='c_panel_topic', PARTITIONS=1, REPLICAS=1, KEY_FORMAT='JSON', VALUE_FORMAT='JSON')
    AS SELECT id,
             CASE WHEN LCASE(color)='pink' THEN 'grey' ELSE color END AS color
       FROM B_TBL
       EMIT CHANGES;

    CREATE TABLE D_TBL
    WITH (KAFKA_TOPIC='d_panel_topic', PARTITIONS=1, REPLICAS=1, KEY_FORMAT='JSON', VALUE_FORMAT='JSON')
    AS SELECT id,
             CASE WHEN LCASE(color)='grey' THEN 'white' ELSE color END AS color
       FROM C_TBL
       EMIT CHANGES;
  "
}
EOF

echo
echo "🔎 5) 再度一覧（作成できたか）..."
cat <<'EOF' | curl -s -X POST $KSQL/ksql \
  -H "Content-Type: application/vnd.ksql.v1+json; charset=utf-8" -d @- \
  | sed -n '1,200p'
{
  "ksql": "SHOW TABLES; SHOW TOPICS;"
}
EOF

echo
echo "🎯 6) 新しいイベントを発火（A を black に更新）..."
docker exec -it pg psql -U postgres -d demo -c \
"UPDATE public.a_panel SET color='black', updated_at=now() WHERE id=1;"

echo
echo "📡 7) B/C/D を再度コンシューム（各5秒）..."
docker exec -it kafka bash -lc "kafka-console-consumer --bootstrap-server $BS --topic b_panel_topic --from-beginning --timeout-ms 5000 || true"
docker exec -it kafka bash -lc "kafka-console-consumer --bootstrap-server $BS --topic c_panel_topic --from-beginning --timeout-ms 5000 || true"
docker exec -it kafka bash -lc "kafka-console-consumer --bootstrap-server $BS --topic d_panel_topic --from-beginning --timeout-ms 5000 || true"

echo
echo "✅ 完了：B/C/D の出力が確認できればOK。まだ0件 or UNKNOWNなら直後の出力を貼ってください。"
