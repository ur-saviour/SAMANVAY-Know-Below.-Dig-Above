ALTER TABLE public.india_administrative_units
  ADD COLUMN IF NOT EXISTS source_state_label text,
  ADD COLUMN IF NOT EXISTS source_state_code text,
  ADD COLUMN IF NOT EXISTS source_unit_code text,
  ADD COLUMN IF NOT EXISTS source_vintage text;

COMMENT ON COLUMN public.india_administrative_units.source_state_label IS
  'Verbatim state or union-territory label from the imported source record; not the current canonical jurisdiction name.';
COMMENT ON COLUMN public.india_administrative_units.source_state_code IS
  'Verbatim source state code from the imported reference dataset; not an LGD code.';
COMMENT ON COLUMN public.india_administrative_units.source_unit_code IS
  'Verbatim source district/unit code from the imported reference dataset; not an LGD code.';
COMMENT ON COLUMN public.india_administrative_units.source_vintage IS
  'Verbatim source vintage/year tag from the imported reference dataset; not a validity date.';
