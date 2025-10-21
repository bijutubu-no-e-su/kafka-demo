CREATE SCHEMA IF NOT EXISTS public;

-- AだけDBに置く（B/C/DはまずKafkaトピックで派生）
DROP TABLE IF EXISTS a_panel;
CREATE TABLE a_panel (
  id SERIAL PRIMARY KEY,
  color TEXT NOT NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT now()
);

INSERT INTO a_panel (color) VALUES ('blue'); -- id=1
