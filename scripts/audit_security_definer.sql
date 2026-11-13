-- Read-only security regression audit for authenticated SECURITY DEFINER RPCs.
-- Run with a database role able to inspect pg_proc and role privileges.
-- This is a catalog/static guard; it does not replace adversarial tests using
-- real anon, Citizen, Officer, Coordinator and Administrator JWT sessions.

DO $samanvay_security_audit$
DECLARE
  item record;
  checked_count integer := 0;
BEGIN
  FOR item IN
    SELECT
      p.oid,
      p.proname,
      p.proconfig,
      pg_get_functiondef(p.oid) AS definition
    FROM pg_catalog.pg_proc AS p
    JOIN pg_catalog.pg_namespace AS n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prosecdef
      AND has_function_privilege('authenticated', p.oid, 'EXECUTE')
    ORDER BY p.proname
  LOOP
    checked_count := checked_count + 1;

    IF has_function_privilege('anon', item.oid, 'EXECUTE') THEN
      RAISE EXCEPTION
        'SECURITY FAILURE: anon can execute public SECURITY DEFINER function %',
        item.proname;
    END IF;

    IF NOT coalesce(array_position(item.proconfig, 'search_path=""'), 0) > 0 THEN
      RAISE EXCEPTION
        'SECURITY FAILURE: public SECURITY DEFINER function % lacks an empty search_path',
        item.proname;
    END IF;

    IF position('auth.uid()' IN lower(item.definition)) = 0 THEN
      RAISE EXCEPTION
        'REVIEW REQUIRED: public SECURITY DEFINER function % does not reference auth.uid()',
        item.proname;
    END IF;
  END LOOP;

  IF checked_count = 0 THEN
    RAISE EXCEPTION
      'SECURITY AUDIT INCONCLUSIVE: no authenticated public SECURITY DEFINER functions were inspected';
  END IF;

  IF NOT has_column_privilege(
    'authenticated', 'public.profiles', 'display_name', 'UPDATE'
  ) THEN
    RAISE EXCEPTION
      'PROFILE POLICY FAILURE: authenticated cannot update display_name';
  END IF;

  IF has_column_privilege(
    'authenticated', 'public.profiles', 'role', 'UPDATE'
  ) THEN
    RAISE EXCEPTION
      'PROFILE PRIVILEGE FAILURE: authenticated can update role';
  END IF;

  IF has_column_privilege(
    'authenticated', 'public.profiles', 'department_id', 'UPDATE'
  ) THEN
    RAISE EXCEPTION
      'PROFILE PRIVILEGE FAILURE: authenticated can update department_id';
  END IF;

  IF has_table_privilege('authenticated', 'public.profiles', 'UPDATE') THEN
    RAISE EXCEPTION
      'PROFILE PRIVILEGE FAILURE: authenticated has unrestricted table UPDATE';
  END IF;

  RAISE NOTICE
    'PASS: inspected % authenticated public SECURITY DEFINER functions; anon execution denied; empty search_path and auth.uid() reference present; profile UPDATE remains display_name-only.',
    checked_count;
END
$samanvay_security_audit$;
