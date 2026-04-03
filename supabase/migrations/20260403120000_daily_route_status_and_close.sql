-- Estado de la jornada: abierta (operario puede facturar) / cerrada (retornos aplicados al stock).
ALTER TABLE daily_routes
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'abierta';

ALTER TABLE daily_routes
  DROP CONSTRAINT IF EXISTS daily_routes_status_check;

ALTER TABLE daily_routes
  ADD CONSTRAINT daily_routes_status_check
  CHECK (status IN ('abierta', 'cerrada'));

COMMENT ON COLUMN daily_routes.status IS 'abierta: en curso; cerrada: sin disponible, retornos sumados a products.stock';

-- Cierra la jornada: el disponible en camión pasa a retornado y vuelve al depósito.
CREATE OR REPLACE FUNCTION public.close_daily_route(p_daily_route_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  r record;
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

  UPDATE daily_routes
  SET status = 'cerrada'
  WHERE id = p_daily_route_id;
END;
$$;

REVOKE ALL ON FUNCTION public.close_daily_route(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.close_daily_route(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.close_daily_route(uuid) TO service_role;
