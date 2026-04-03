-- Gastos extras declarados al cerrar la jornada (descripción + monto).
CREATE TABLE IF NOT EXISTS public.daily_route_expenses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  daily_route_id uuid NOT NULL REFERENCES public.daily_routes(id) ON DELETE CASCADE,
  description text NOT NULL,
  amount numeric(14, 2) NOT NULL CHECK (amount >= 0),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_daily_route_expenses_daily_route_id
  ON public.daily_route_expenses(daily_route_id);

COMMENT ON TABLE public.daily_route_expenses IS 'Gastos extra registrados por el operario al terminar el día';

ALTER TABLE public.daily_route_expenses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "daily_route_expenses_select_authenticated"
  ON public.daily_route_expenses FOR SELECT
  TO authenticated
  USING (true);

-- Sustituye cierre de día: acepta arreglo JSON de gastos [{ "description": "...", "amount": 12.5 }, ...]
DROP FUNCTION IF EXISTS public.close_daily_route(uuid);

CREATE OR REPLACE FUNCTION public.close_daily_route(
  p_daily_route_id uuid,
  p_expenses jsonb DEFAULT '[]'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  r record;
  elem jsonb;
  desc_txt text;
  amt numeric;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM daily_routes
    WHERE id = p_daily_route_id AND status = 'abierta'
  ) THEN
    RAISE EXCEPTION 'Ruta del día no encontrada o ya cerrada';
  END IF;

  FOR r IN
    SELECT product_id, available_quantity, returned_quantity
    FROM daily_route_products
    WHERE daily_route_id = p_daily_route_id
      AND COALESCE(available_quantity, 0) > 0
  LOOP
    UPDATE products
    SET stock = stock + r.available_quantity
    WHERE id = r.product_id;

    UPDATE daily_route_products
    SET
      returned_quantity =
        COALESCE(returned_quantity, 0) + r.available_quantity,
      available_quantity = 0
    WHERE daily_route_id = p_daily_route_id
      AND product_id = r.product_id;
  END LOOP;

  IF p_expenses IS NOT NULL AND jsonb_typeof(p_expenses) = 'array' THEN
    FOR elem IN SELECT value FROM jsonb_array_elements(p_expenses)
    LOOP
      desc_txt := trim(COALESCE(elem->>'description', ''));
      IF desc_txt = ''
         AND (elem->>'amount' IS NULL OR trim(elem->>'amount') = '')
      THEN
        CONTINUE;
      END IF;

      IF desc_txt = '' THEN
        RAISE EXCEPTION 'Cada gasto con monto debe incluir una descripción';
      END IF;

      IF elem->>'amount' IS NULL OR trim(elem->>'amount') = '' THEN
        RAISE EXCEPTION 'Cada gasto debe incluir un monto: %', desc_txt;
      END IF;

      amt := (elem->>'amount')::numeric;
      IF amt < 0 THEN
        RAISE EXCEPTION 'Los montos de gastos no pueden ser negativos';
      END IF;

      INSERT INTO daily_route_expenses (daily_route_id, description, amount)
      VALUES (p_daily_route_id, desc_txt, amt);
    END LOOP;
  END IF;

  UPDATE daily_routes
  SET status = 'cerrada'
  WHERE id = p_daily_route_id;
END;
$$;

REVOKE ALL ON FUNCTION public.close_daily_route(uuid, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.close_daily_route(uuid, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.close_daily_route(uuid, jsonb) TO service_role;
