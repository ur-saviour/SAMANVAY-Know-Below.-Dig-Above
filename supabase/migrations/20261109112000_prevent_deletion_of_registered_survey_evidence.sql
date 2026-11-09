create or replace function public.can_delete_utility_asset_evidence_path(
  p_asset_id text,p_actor_id uuid,p_object_path text
) returns boolean language plpgsql stable security definer set search_path = ''
as $$
begin
  if not public.can_access_utility_asset_evidence_path(p_asset_id,p_actor_id) then return false; end if;
  if p_object_path is null or p_object_path !~ ('^'||p_asset_id||'/'||p_actor_id::text||'/[A-Za-z0-9._-]{1,180}\.(pdf|jpg|jpeg|png|webp)$') then return false; end if;
  return not exists (select 1 from gis.asset_survey_evidence e where e.evidence_storage_path=p_object_path);
end;
$$;
revoke all on function public.can_delete_utility_asset_evidence_path(text,uuid,text) from public,anon;
grant execute on function public.can_delete_utility_asset_evidence_path(text,uuid,text) to authenticated,service_role;
drop policy if exists "SAMANVAY asset evidence delete by uploader" on storage.objects;
create policy "SAMANVAY asset evidence delete by uploader"
on storage.objects for delete to authenticated using (
  bucket_id='samanvay-asset-survey-evidence'
  and public.can_delete_utility_asset_evidence_path((storage.foldername(name))[1],(select auth.uid()),name)
);