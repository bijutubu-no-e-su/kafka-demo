CREATE TABLE IF NOT EXISTS public.a_panel (
  id INT PRIMARY KEY,
  color TEXT NOT NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT now ()
);

INSERT INTO
  public.a_panel (id, color)
VALUES
  (1, 'blue') ON CONFLICT (id) DO
UPDATE
SET
  color = EXCLUDED.color;

CREATE TABLE IF NOT EXISTS public.b_panel (id INT PRIMARY KEY, color TEXT NOT NULL);

CREATE TABLE IF NOT EXISTS public.c_panel (id INT PRIMARY KEY, color TEXT NOT NULL);

CREATE TABLE IF NOT EXISTS public.d_panel (id INT PRIMARY KEY, color TEXT NOT NULL);
