-- Add return-reason flags for invoice items.
-- New app fields:
--   quality_return (bool)
--   expiration_return (bool)
--
-- This migration is defensive:
-- - Creates columns only if they do not exist.
-- - Backfills from legacy Spanish columns if present.
-- - Keeps existing data safe.

alter table public.invoice_items
  add column if not exists quality_return boolean not null default false,
  add column if not exists expiration_return boolean not null default false;

do $$
declare
  has_legacy_quality boolean;
  has_legacy_expiration boolean;
begin
  select exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'invoice_items'
      and column_name = 'devolucion_calidad'
  )
  into has_legacy_quality;

  select exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'invoice_items'
      and column_name = 'devolucion_vencimiento'
  )
  into has_legacy_expiration;

  if has_legacy_quality then
    execute '
      update public.invoice_items
      set quality_return = coalesce(devolucion_calidad, false)
      where quality_return = false
    ';
  end if;

  if has_legacy_expiration then
    execute '
      update public.invoice_items
      set expiration_return = coalesce(devolucion_vencimiento, false)
      where expiration_return = false
    ';
  end if;
end $$;
