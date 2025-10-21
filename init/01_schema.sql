-- 初期スキーマ: 単純なパネルテーブル
-- このデモでは `a_panel` の変更のみを DB 側に持ち、
-- ksqlDB で派生ストリーム（B/C/D）を作る想定です。
CREATE SCHEMA IF NOT EXISTS public;

-- 既存のテーブルがあれば削除して初期化（開発用）
DROP TABLE IF EXISTS a_panel;

CREATE TABLE a_panel (
  -- 自動採番の主キー
  id SERIAL PRIMARY KEY,
  -- 表示色（任意の文字列）
  color TEXT NOT NULL,
  -- 最終更新時刻（デフォルトで now() が入る）
  updated_at TIMESTAMP NOT NULL DEFAULT now ()
);

-- 初期データを 1 行挿入（UI は id=1 を参照して表示する）
INSERT INTO
  a_panel (color)
VALUES
  ('blue');

-- id=1
