-- Keep Storage RLS helper functions outside the exposed public Data API.
-- These helpers are invoked only by storage.objects policies and bind all
-- actor identity to auth.uid(); clients must not call them as public RPCs.

create or replace function private.can_access_utility_asset_evidence_path(
  p_asset_id text,
  p_actor_id uuid
) returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $function$
begin
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

create or replace function private.can_delete_utility_asset_evidence_path(
  p_asset_id text,
  p_actor_id uuid,
  p_object_path text
) returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $function$
begin
  if not private.can_access_utility_asset_evidence_path(p_asset_id, p_actor_id) then
    return false;
  end if;

  if p_object_path is null or p_object_path !~ (
    '^'||p_asset_id||'/'||p_actor_id::text||'/[A-Za-z0-9._-]{1,180}\\.(pdf|jpg|jpeg|png|webp)$'
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

-- Storage evaluates these expressions as the authenticated caller.
-- private is not an exposed Data API schema; keep explicit minimum grants.
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

revoke all on function private.can_access_utility_asset_evidence_path(text,uuid)
  from public, anon, authenticated, service_role;
revoke all on function private.can_delete_utility_asset_evidence_path(text,uuid,text)
  from public, anon, authenticated, service_role;
grant execute on function private.can_access_utility_asset_evidence_path(text,uuid)
  to authenticated;
grant execute on function private.can_delete_utility_asset_evidence_path(text,uuid,text)
  to authenticated;

drop policy if exists "SAMANVAY asset evidence upload by owner department" on storage.objects;
create policy "SAMANVAY asset evidence upload by owner department"
on storage.objects for insert to authenticated with check (
  bucket_id = 'samanvay-asset-survey-evidence'
  and (storage.foldername(name))[2] = (select auth.uid())::text
  and private.can_access_utility_asset_evidence_path(
    (storage.foldername(name))[1], (select auth.uid())
  )
);

drop policy if exists "SAMANVAY asset evidence read by owner department" on storage.objects;
create policy "SAMANVAY asset evidence read by owner department"
on storage.objects for select to authenticated using (
  bucket_id = 'samanvay-asset-survey-evidence'
  and private.can_access_utility_asset_evidence_path(
    (storage.foldername(name))[1], (select auth.uid())
  )
);

drop policy if exists "SAMANVAY asset evidence delete by uploader" on storage.objects;
create policy "SAMANVAY asset evidence delete by uploader"
on storage.objects for delete to authenticated using (
  bucket_id = 'samanvay-asset-survey-evidence'
  and (storage.foldername(name))[2] = (select auth.uid())::text
  and private.can_delete_utility_asset_evidence_path(
    (storage.foldername(name))[1], (select auth.uid()), name
  )
);

-- No public or authenticated RPC entry points remain for these internal helpers.
drop function public.can_delete_utility_asset_evidence_path(text,uuid,text);
drop function public.can_access_utility_asset_evidence_path(text,uuid);

notify pgrst, 'reload schema';
