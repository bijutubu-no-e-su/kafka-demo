SET 'auto.offset.reset' = 'earliest';

-- 全パネルのDebeziumトピックを統計用に読み取り（変換はしない）
CREATE STREAM IF NOT EXISTS a_panel_events (id INT, color VARCHAR, updated_at BIGINT)
WITH (KAFKA_TOPIC = 'pg.public.a_panel', VALUE_FORMAT = 'JSON');

CREATE STREAM IF NOT EXISTS b_panel_events (id INT, color VARCHAR, updated_at BIGINT)
WITH (KAFKA_TOPIC = 'pg.public.b_panel', VALUE_FORMAT = 'JSON');

CREATE STREAM IF NOT EXISTS c_panel_events (id INT, color VARCHAR, updated_at BIGINT)
WITH (KAFKA_TOPIC = 'pg.public.c_panel', VALUE_FORMAT = 'JSON');

CREATE STREAM IF NOT EXISTS d_panel_events (id INT, color VARCHAR, updated_at BIGINT)
WITH (KAFKA_TOPIC = 'pg.public.d_panel', VALUE_FORMAT = 'JSON');

-- 色の変更回数を集計
CREATE TABLE IF NOT EXISTS color_stats AS
SELECT 
  color,
  COUNT(*) as total_changes
FROM a_panel_events 
GROUP BY color;

-- 最新の更新時刻を追跡
CREATE TABLE IF NOT EXISTS latest_updates AS
SELECT 
  'a_panel' as panel_name,
  LATEST_BY_OFFSET(color) as current_color,
  LATEST_BY_OFFSET(updated_at) as last_updated
FROM a_panel_events
GROUP BY 'a_panel';
