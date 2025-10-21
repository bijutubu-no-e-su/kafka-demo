#!/bin/sh
set -e

CONNECT=${CONNECT_URL:-http://connect:8083}
echo "[init] waiting Connect..."
until curl -fsS "$CONNECT/"; do sleep 1; done

echo "[init] register Debezium source (A/B/C/D)"
# Use POST to create the connector if it doesn't exist. Use database.server.name
# (Debezium Postgres connector expects this) rather than topic.prefix.
curl -fsS -X POST "$CONNECT/connectors" \
  -H 'Content-Type: application/json' -d '{
    "name": "debezium-a",
    "config": {
      "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
      "database.hostname": "pg",
      "database.port": "5432",
      "database.user": "postgres",
      "database.password": "postgres",
      "database.dbname": "demo",
      "database.server.name": "pg",
      "slot.name": "a_slot",
      "publication.name": "a_pub",
      "publication.autocreate.mode": "filtered",
      "plugin.name": "pgoutput",
      "table.include.list": "public.a_panel,public.b_panel,public.c_panel,public.d_panel",
      "include.schema.changes": "false",
      "tombstones.on.delete": "false",

      "transforms": "unwrap,addkey,extractKey",
      "transforms.unwrap.type": "io.debezium.transforms.ExtractNewRecordState",
      "transforms.unwrap.add.fields": "op,ts_ms",

      "transforms.addkey.type": "org.apache.kafka.connect.transforms.ValueToKey",
      "transforms.addkey.fields": "id",
      "transforms.extractKey.type": "org.apache.kafka.connect.transforms.ExtractField$Key",
      "transforms.extractKey.field": "id",

      "key.converter": "org.apache.kafka.connect.json.JsonConverter",
      "value.converter": "org.apache.kafka.connect.json.JsonConverter",
      "key.converter.schemas.enable": "false",
      "value.converter.schemas.enable": "false"
    }
  }' || true

# If connector already exists, update its config via PUT to ensure idempotency
curl -fsS -X PUT "$CONNECT/connectors/debezium-a/config" \
  -H 'Content-Type: application/json' -d '{
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "database.hostname": "pg",
    "database.port": "5432",
    "database.user": "postgres",
    "database.password": "postgres",
    "database.dbname": "demo",
    "database.server.name": "pg",
    "slot.name": "a_slot",
    "publication.name": "a_pub",
    "publication.autocreate.mode": "filtered",
    "plugin.name": "pgoutput",
    "table.include.list": "public.a_panel,public.b_panel,public.c_panel,public.d_panel",
    "include.schema.changes": "false",
    "tombstones.on.delete": "false",

    "transforms": "unwrap,addkey,extractKey",
    "transforms.unwrap.type": "io.debezium.transforms.ExtractNewRecordState",
    "transforms.unwrap.add.fields": "op,ts_ms",

    "transforms.addkey.type": "org.apache.kafka.connect.transforms.ValueToKey",
    "transforms.addkey.fields": "id",
    "transforms.extractKey.type": "org.apache.kafka.connect.transforms.ExtractField$Key",
    "transforms.extractKey.field": "id",

    "key.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter": "org.apache.kafka.connect.json.JsonConverter",
    "key.converter.schemas.enable": "false",
    "value.converter.schemas.enable": "false"
  }' || true
echo
echo "[init] done."
