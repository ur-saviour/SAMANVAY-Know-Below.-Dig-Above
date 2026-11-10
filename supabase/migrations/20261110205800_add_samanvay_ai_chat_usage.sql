-- Privacy-preserving quota accounting for SAMANVAY AI chat.
-- Chat text and conversation history are intentionally not stored.

create table if not exists public.ai_chat_usage_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create index if not exists ai_chat_usage_events_user_created_idx
  on public.ai_chat_usage_events (user_id, created_at desc);

alter table public.ai_chat_usage_events enable row level security;
revoke all on table public.ai_chat_usage_events from public, anon, authenticated;

create or replace function public.reserve_samanvay_ai_turn(
  p_user_id uuid,
  p_limit integer default 20
)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog, public
as $function$
declare
  v_recent_count integer;
begin
  if p_user_id is null or p_limit is null or p_limit < 1 or p_limit > 100 then
    return false;
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_user_id::text, 73)
  );

  delete from public.ai_chat_usage_events
  where created_at < pg_catalog.now() - interval '7 days';

  select count(*)::integer
    into v_recent_count
  from public.ai_chat_usage_events
  where user_id = p_user_id
    and created_at >= pg_catalog.now() - interval '24 hours';

  if v_recent_count >= p_limit then
    return false;
  end if;

  insert into public.ai_chat_usage_events(user_id)
  values (p_user_id);

  return true;
end;
$function$;

revoke all on function public.reserve_samanvay_ai_turn(uuid, integer)
  from public, anon, authenticated;
grant execute on function public.reserve_samanvay_ai_turn(uuid, integer)
  to service_role;
