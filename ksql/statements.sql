-- ksqlDB: A の CDC (Debezium の JSON) を受け取り、派生ストリーム / テーブルで
-- 色の変換（B -> C -> D）を行うサンプル定義です。
--
-- コメントは各行に詳しく書いてあります。実行順序や動作に影響を与えない
-- 目的で説明を追加しているだけなので、SQL の動作自体は変更していません。
-- オフセットリセットのポリシーを指定します。
-- 'latest' にすると既存トピックの最終オフセット以降のみを読みます。
-- デモで既存データも読みたい場合は 'earliest' にすることを検討してください。
SET
  'auto.offset.reset' = 'latest';

-- ---------------------------------------------------------------------------
-- A_SRC: Debezium が出力するトピック（pg.public.a_panel）をそのまま読む
-- - Debezium の出力を事前に unwrap (Connect の Single Message Transform 等) して
--   VALUE に行データ（または envelope）を入れている想定です。
-- - ここでは VALUE_FORMAT = 'JSON' を指定し、JSON で来ることを期待しています。
-- - フィールドの型はこのサンプルの想定型です。必要に応じて型を合わせてください。
CREATE
OR REPLACE STREAM A_SRC (
  id INT, -- 行の主キー（Postgres の id）
  color STRING, -- パネルの色を示すフィールド
  updated_at STRING, -- 更新時刻（文字列で来る場合がある）
  op STRING, -- Debezium の操作種別 (c=create, u=update, d=delete など)
  ts_ms BIGINT -- Debezium が付与するタイムスタンプ（ミリ秒）
)
WITH
  (
    KAFKA_TOPIC = 'pg.public.a_panel', -- Kafka の入力トピック名（Debezium が使う例）
    VALUE_FORMAT = 'JSON' -- 値のフォーマット
  );

-- ---------------------------------------------------------------------------
-- A_REKEY: キー（パーティションキー）を id に再設定するためのストリーム
-- - PARTITION BY を使うと ksqlDB が新しいトピックに対して書き出すため、
--   後続の集約（GROUP BY）や TABLE 化が効率よく行えます。
-- - KEY_FORMAT / VALUE_FORMAT を JSON にして、出力トピックを明示しています。
CREATE
OR REPLACE STREAM A_REKEY
WITH
  (
    KAFKA_TOPIC = 'a_rekey_topic', -- 再パーティション後の中間トピック名
    KEY_FORMAT = 'JSON',
    VALUE_FORMAT = 'JSON'
  ) AS
SELECT
  id,
  color,
  updated_at,
  op,
  ts_ms
FROM
  A_SRC
PARTITION BY
  id EMIT CHANGES;

-- PARTITION BY で id をキーにして再配信する（永続化はしない）
-- ---------------------------------------------------------------------------
-- B_TBL: 最新の色をテーブルとして保持（black -> pink の変換を適用）
-- - TABLE を作ることで各 id 毎の最新値を保持（状態管理）できます。
-- - LATEST_BY_OFFSET が使われているのは、ストリーム中の最新の値を選ぶため。
-- - GROUP BY id により、id ごとの集約（状態保持）になります。
CREATE
OR REPLACE TABLE B_TBL
WITH
  (
    KAFKA_TOPIC = 'b_panel_topic', -- B の結果を出すトピック（下流 consumer が使う想定）
    KEY_FORMAT = 'JSON',
    VALUE_FORMAT = 'JSON'
  ) AS
SELECT
  id,
  LATEST_BY_OFFSET (
    CASE
      WHEN LCASE (color) = 'black' THEN 'pink' -- 小文字化して 'black' を判定 → 'pink' に変換
      ELSE color -- それ以外はそのまま
    END
  ) AS color
FROM
  A_REKEY
GROUP BY
  id EMIT CHANGES;

-- GROUP BY してテーブル（状態）を作る
-- ---------------------------------------------------------------------------
-- C_TBL: B の出力を受け取り追加の変換（pink -> grey）を適用
-- - ここでは TABLE から直接 SELECT しているため、B_TBL の現在値を使って
--   C_TBL の状態を更新します。
CREATE
OR REPLACE TABLE C_TBL
WITH
  (
    KAFKA_TOPIC = 'c_panel_topic',
    KEY_FORMAT = 'JSON',
    VALUE_FORMAT = 'JSON'
  ) AS
SELECT
  id,
  CASE
    WHEN LCASE (color) = 'pink' THEN 'grey' -- pink を grey に変換
    ELSE color
  END AS color
FROM
  B_TBL EMIT CHANGES;

-- ---------------------------------------------------------------------------
-- D_TBL: C の出力を受け取り最終変換（grey -> white）を適用
-- - 最終的に UI 等が参照するトピックをここで作る（d_panel_topic）想定
CREATE
OR REPLACE TABLE D_TBL
WITH
  (
    KAFKA_TOPIC = 'd_panel_topic',
    KEY_FORMAT = 'JSON',
    VALUE_FORMAT = 'JSON'
  ) AS
SELECT
  id,
  CASE
    WHEN LCASE (color) = 'grey' THEN 'white' -- grey を white に変換
    ELSE color
  END AS color
FROM
  C_TBL EMIT CHANGES;

-- ---------------------------------------------------------------------------
-- NOTES:
-- - LCASE() を使っているのは大文字/小文字のばらつきに耐性を持たせるためです。
-- - VALUE_FORMAT / KEY_FORMAT の指定は利用する ksqlDB と Kafka の設定に依存します。
-- - Debezium の出力が envelope 形式（payload.after）になっている場合は、
--   A_SRC の定義や前段での SMT（Single Message Transform）によって
--   unwrap (after を直接値に展開) しておく必要があります。
-- - テスト時は 'auto.offset.reset' = 'earliest' にして既存のメッセージを再処理
--   すると動作確認がしやすくなります。
