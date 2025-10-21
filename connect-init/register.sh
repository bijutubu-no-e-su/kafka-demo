curl -fsS -X PUT "$CONNECT_URL/connectors/a-source/config" \
  -H 'Content-Type: application/json' -d '{
    "name": "a-source",
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "database.hostname": "pg",
    "database.port": "5432",
    "database.user": "postgres",
    "database.password": "postgres",
    "database.dbname": "demo",
    "topic.prefix": "pg",
    "schema.include.list": "public",
    "table.include.list": "public.a_panel,public.b_panel,public.c_panel,public.d_panel",
    "publication.autocreate.mode": "filtered",
    "slot.name": "debezium_slot_demo",
    "include.schema.changes": "false",
    "tombstones.on.delete": "false",
    "decimal.handling.mode": "string",
    "transforms": "unwrap",
    "transforms.unwrap.type": "io.debezium.transforms.ExtractNewRecordState",
    "transforms.unwrap.drop.tombstones": "true",
    "value.converter":"org.apache.kafka.connect.json.JsonConverter",
    "value.converter.schemas.enable":"false",
    "key.converter":"org.apache.kafka.connect.storage.StringConverter"
  }'
