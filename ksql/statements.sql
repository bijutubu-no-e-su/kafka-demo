-- ksql/statements.sql
SET
  'auto.offset.reset' = 'earliest';

-- Debezium（unwrap後, スキーマレスJSON）を読む
CREATE STREAM IF NOT EXISTS A_SRC (id INT, color VARCHAR, updated_at BIGINT)
WITH
  (
    KAFKA_TOPIC = 'pg.public.a_panel',
    VALUE_FORMAT = 'JSON'
  );

-- A → B
CREATE STREAM IF NOT EXISTS B_STREAM
WITH
  (
    KAFKA_TOPIC = 'b_panel_topic',
    VALUE_FORMAT = 'JSON'
  ) AS
SELECT
  id,
  CASE
    WHEN LCASE (color) = 'blue' THEN 'red'
    ELSE 'blue'
  END AS color,
  updated_at
FROM
  A_SRC EMIT CHANGES;

-- B → C
CREATE STREAM IF NOT EXISTS B_SRC (id INT, color VARCHAR, updated_at BIGINT)
WITH
  (
    KAFKA_TOPIC = 'b_panel_topic',
    VALUE_FORMAT = 'JSON'
  );

CREATE STREAM IF NOT EXISTS C_STREAM
WITH
  (
    KAFKA_TOPIC = 'c_panel_topic',
    VALUE_FORMAT = 'JSON'
  ) AS
SELECT
  id,
  CASE
    WHEN LCASE (color) = 'red' THEN 'green'
    ELSE 'yellow'
  END AS color,
  updated_at
FROM
  B_SRC EMIT CHANGES;

-- C → D
CREATE STREAM IF NOT EXISTS C_SRC (id INT, color VARCHAR, updated_at BIGINT)
WITH
  (
    KAFKA_TOPIC = 'c_panel_topic',
    VALUE_FORMAT = 'JSON'
  );

CREATE STREAM IF NOT EXISTS D_STREAM
WITH
  (
    KAFKA_TOPIC = 'd_panel_topic',
    VALUE_FORMAT = 'JSON'
  ) AS
SELECT
  id,
  'purple' AS color,
  updated_at
FROM
  C_SRC EMIT CHANGES;
