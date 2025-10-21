-- ksqlDB のストリーム定義例
-- A_STREAM は Debezium が作成するトピック（例: pg.public.a_panel）を読み込むためのストリーム
-- VALUE_FORMAT は Debezium の JSON 出力を想定して 'JSON' を指定しています。
CREATE STREAM A_STREAM (
  id INT KEY,
  color VARCHAR,
  updated_at BIGINT,
  -- Debezium が付与する操作種別（c=create/u=update/d=delete）などを受け取りたい場合に使える列
  __op VARCHAR,
  -- Debezium が付与するタイムスタンプ（ミリ秒）
  __ts_ms BIGINT
)
WITH
  (
    KAFKA_TOPIC = 'pg.public.a_panel',
    VALUE_FORMAT = 'JSON'
  );

-- B_STREAM: A_STREAM の color に対して単純な変換ロジックを適用
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

-- C_STREAM: B_STREAM の結果をさらに変換
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

-- D_STREAM: さらに変換して最終ストリームを作る
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
