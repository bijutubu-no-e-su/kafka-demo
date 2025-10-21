CREATE STREAM A_STREAM (
  id INT KEY,
  color VARCHAR,
  updated_at BIGINT,
  __op VARCHAR,
  __ts_ms BIGINT
)
WITH
  (
    KAFKA_TOPIC = 'pg.public.a_panel',
    VALUE_FORMAT = 'JSON'
  );

-- B_STREAM
CREATE STREAM B_STREAM AS
SELECT
  id,
  CASE
    WHEN color = 'black' THEN 'pink'
    ELSE color
  END AS color,
  __ts_ms
FROM
  A_STREAM EMIT CHANGES;

-- C_STREAM
CREATE STREAM C_STREAM AS
SELECT
  id,
  CASE
    WHEN color = 'pink' THEN 'grey'
    ELSE color
  END AS color,
  __ts_ms
FROM
  B_STREAM EMIT CHANGES;

-- D_STREAM
CREATE STREAM D_STREAM AS
SELECT
  id,
  CASE
    WHEN color = 'grey' THEN 'white'
    ELSE color
  END AS color,
  __ts_ms
FROM
  C_STREAM EMIT CHANGES;
