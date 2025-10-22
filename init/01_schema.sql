-- 共通: updated_at を UPDATE ごとに now() へ更新する関数
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END$$;

-- A
CREATE TABLE IF NOT EXISTS public.a_panel (
  id INT PRIMARY KEY,
  color TEXT NOT NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT now()
);
DROP TRIGGER IF EXISTS trg_a_panel_updated_at ON public.a_panel;
CREATE TRIGGER trg_a_panel_updated_at
BEFORE UPDATE ON public.a_panel
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- B
CREATE TABLE IF NOT EXISTS public.b_panel (
  id INT PRIMARY KEY,
  color TEXT NOT NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT now()
);
DROP TRIGGER IF EXISTS trg_b_panel_updated_at ON public.b_panel;
CREATE TRIGGER trg_b_panel_updated_at
BEFORE UPDATE ON public.b_panel
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- C
CREATE TABLE IF NOT EXISTS public.c_panel (
  id INT PRIMARY KEY,
  color TEXT NOT NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT now()
);
DROP TRIGGER IF EXISTS trg_c_panel_updated_at ON public.c_panel;
CREATE TRIGGER trg_c_panel_updated_at
BEFORE UPDATE ON public.c_panel
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- D
CREATE TABLE IF NOT EXISTS public.d_panel (
  id INT PRIMARY KEY,
  color TEXT NOT NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT now()
);
DROP TRIGGER IF EXISTS trg_d_panel_updated_at ON public.d_panel;
CREATE TRIGGER trg_d_panel_updated_at
BEFORE UPDATE ON public.d_panel
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- デモ用 初期レコード（存在時は色とupdated_atを更新）
INSERT INTO public.a_panel (id, color) VALUES (1, 'blue')
ON CONFLICT (id) DO UPDATE SET color = EXCLUDED.color, updated_at = now();

INSERT INTO public.b_panel (id, color) VALUES (1, 'blue')
ON CONFLICT (id) DO UPDATE SET color = EXCLUDED.color, updated_at = now();

INSERT INTO public.c_panel (id, color) VALUES (1, 'blue')
ON CONFLICT (id) DO UPDATE SET color = EXCLUDED.color, updated_at = now();

INSERT INTO public.d_panel (id, color) VALUES (1, 'blue')
ON CONFLICT (id) DO UPDATE SET color = EXCLUDED.color, updated_at = now();
