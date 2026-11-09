create or replace function public.can_access_utility_asset_evidence_path(
  p_asset_id text,
  p_actor_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path to ''
as $function$
begin
  -- Bind the actor argument to the authenticated caller. This helper is
  -- also executable by authenticated clients through storage RLS policies.
  if p_actor_id is null
     or p_actor_id is distinct from (select auth.uid()) then
    return false;
  end if;

  if p_asset_id is null
     or p_asset_id !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
    return false;
  end if;

  return exists (
    select 1
    from public.profiles p
    join gis.underground_assets a
      on a.owner_department_id = p.department_id
    where p.id = (select auth.uid())
      and p.role = 'department'
      and a.id = p_asset_id::uuid
      and a.import_run_id is not null
  );
end;
$function$;

create or replace function public.can_delete_utility_asset_evidence_path(
  p_asset_id text,
  p_actor_id uuid,
  p_object_path text
)
returns boolean
language plpgsql
stable
security definer
set search_path to ''
as $function$
begin
  if not public.can_access_utility_asset_evidence_path(p_asset_id, p_actor_id) then
    return false;
  end if;

  if p_object_path is null or p_object_path !~ (
    '^'||p_asset_id||'/'||p_actor_id::text||'/[A-Za-z0-9._-]{1,180}\.(pdf|jpg|jpeg|png|webp)$'
  ) then
    return false;
  end if;

  return not exists (
    select 1
    from gis.asset_survey_evidence e
    where e.evidence_storage_path = p_object_path
  );
end;
$function$;
