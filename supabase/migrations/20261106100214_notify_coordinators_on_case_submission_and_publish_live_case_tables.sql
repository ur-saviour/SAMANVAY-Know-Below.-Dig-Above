-- Notify authorised platform operators when a new infrastructure case is submitted.
create or replace function public.samanvay_notify_new_case()
returns trigger
language plpgsql
security definer
set search_path=''
as $function$
begin
  insert into public.user_notifications(
    recipient_id,request_id,notification_type,title,body,data
  )
  select p.id,new.id,'system','New infrastructure case submitted',
    'A new case has been submitted and is awaiting coordination review.',
    jsonb_build_object(
      'case_category',new.case_category,
      'work_activity',new.work_activity
    )
  from public.profiles p
  where p.role in ('admin','coordinator');

  return new;
end;
$function$;

drop trigger if exists samanvay_notify_new_case
  on public.excavation_requests;
create trigger samanvay_notify_new_case
  after insert on public.excavation_requests
  for each row execute function public.samanvay_notify_new_case();

revoke all on function public.samanvay_notify_new_case()
  from public,anon,authenticated;

-- Publish permission-filtered case records for realtime Flutter subscriptions.
do $$
begin
  if exists(select 1 from pg_publication where pubname='supabase_realtime') then
    if not exists(
      select 1 from pg_publication_tables
      where pubname='supabase_realtime' and schemaname='public'
        and tablename='excavation_requests'
    ) then
      execute 'alter publication supabase_realtime add table public.excavation_requests';
    end if;
    if not exists(
      select 1 from pg_publication_tables
      where pubname='supabase_realtime' and schemaname='public'
        and tablename='request_department_reviews'
    ) then
      execute 'alter publication supabase_realtime add table public.request_department_reviews';
    end if;
  end if;
end;
$$;
