#!/bin/bash
set -euo pipefail

KSQL=http://localhost:8088
BS=kafka:9092

echo "🔎 A_REKEY にイベントが来ているかを軽く確認（無ければDBをUPDATEして発火してね）"
curl -sS -X POST $KSQL/query-stream \
  -H 'Content-Type: application/vnd.ksql.v1+json; charset=utf-8' \
  -d '{"sql":"SELECT id, color FROM A_REKEY EMIT CHANGES LIMIT 3;"}' || true
echo

echo "🧹 B/C/D をいったんDROP（トピックは残してOK）"
for name in D_TBL C_TBL B_TBL; do
  cat <<EOF | curl -s -X POST $KSQL/ksql \
    -H "Content-Type: application/vnd.ksql.v1+json; charset=utf-8" -d @- >/dev/null || true
{
  "ksql": "DROP TABLE IF EXISTS $name;"
}
EOF
done

echo "🛠 B_TBL を“集約あり”で作り直し（LATEST_BY_OFFSET を使用）"
cat <<'EOF' | curl -s -X POST http://localhost:8088/ksql \
  -H "Content-Type: application/vnd.ksql.v1+json; charset=utf-8" -d @- \
  | sed -n '1,120p'
{
  "ksql": "
    CREATE TABLE B_TBL
    WITH (KAFKA_TOPIC='b_panel_topic', PARTITIONS=1, REPLICAS=1, KEY_FORMAT='JSON', VALUE_FORMAT='JSON')
    AS SELECT
         id,
         LATEST_BY_OFFSET(CASE WHEN LCASE(color)='black' THEN 'pink' ELSE color END) AS color
       FROM A_REKEY
       GROUP BY id
       EMIT CHANGES;
  "
}
EOF

echo "🛠 C_TBL / D_TBL をTABLE→TABLEで再作成（非集約でOK）"
cat <<'EOF' | curl -s -X POST http://localhost:8088/ksql \
  -H "Content-Type: application/vnd.ksql.v1+json; charset=utf-8" -d @- \
  | sed -n '1,120p'
{
  "ksql": "
    CREATE TABLE C_TBL
    WITH (KAFKA_TOPIC='c_panel_topic', PARTITIONS=1, REPLICAS=1, KEY_FORMAT='JSON', VALUE_FORMAT='JSON')
    AS SELECT
         id,
         CASE WHEN LCASE(color)='pink' THEN 'grey' ELSE color END AS color
       FROM B_TBL
       EMIT CHANGES;

    CREATE TABLE D_TBL
    WITH (KAFKA_TOPIC='d_panel_topic', PARTITIONS=1, REPLICAS=1, KEY_FORMAT='JSON', VALUE_FORMAT='JSON')
    AS SELECT
         id,
         CASE WHEN LCASE(color)='grey' THEN 'white' ELSE color END AS color
       FROM C_TBL
       EMIT CHANGES;
  "
}
EOF

echo "🔎 一覧で生成を確認"
cat <<'EOF' | curl -s -X POST http://localhost:8088/ksql \
  -H "Content-Type: application/vnd.ksql.v1+json; charset=utf-8" -d @- \
  | sed -n '1,200p'
{
  "ksql": "SHOW TABLES; SHOW TOPICS;"
}
EOF

echo "🎯 新しいイベントを発火（A を black に更新）"
docker exec -it pg psql -U postgres -d demo -c \
"UPDATE public.a_panel SET color='black', updated_at=now() WHERE id=1;"

echo "📡 B/C/D の出力を確認（各5秒）"
docker exec -it kafka bash -lc "kafka-console-consumer --bootstrap-server $BS --topic b_panel_topic --from-beginning --timeout-ms 5000 || true"
docker exec -it kafka bash -lc "kafka-console-consumer --bootstrap-server $BS --topic c_panel_topic --from-beginning --timeout-ms 5000 || true"
docker exec -it kafka bash -lc "kafka-console-consumer --bootstrap-server $BS --topic d_panel_topic --from-beginning --timeout-ms 5000 || true"

echo "✅ 修正完了：pink → grey → white が出ればOK"
