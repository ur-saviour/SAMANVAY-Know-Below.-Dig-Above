-- Create an audited, admin/coordinator-only queue for ULB-to-district reconciliation.
-- This intentionally seeds no proposed parent district: the 5,050-row source mirror
-- contains no districtCode/districtName fields.

create table if not exists public.india_ulb_district_reconciliation (
  id uuid primary key default gen_random_uuid(),
  ulb_unit_id uuid not null unique
    references public.india_administrative_units(id) on delete cascade,
  state_ut_id uuid not null
    references public.india_state_uts(id) on delete restrict,
  source_system text not null,
  source_vintage text,
  resolution_status text not null default 'unmapped'
    check (resolution_status in ('unmapped','candidate','verified','rejected')),
  proposed_district_unit_id uuid
    references public.india_administrative_units(id) on delete restrict,
  mapping_source text,
  mapping_source_url text,
  mapping_source_reference text,
  rationale text,
  last_verified_by uuid references auth.users(id) on delete set null,
  last_verified_at timestamptz,
  created_by uuid references auth.users(id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint india_ulb_district_verified_requires_evidence check (
    resolution_status <> 'verified'
    or (
      proposed_district_unit_id is not null
      and nullif(btrim(mapping_source), '') is not null
      and nullif(btrim(mapping_source_url), '') is not null
      and nullif(btrim(rationale), '') is not null
      and last_verified_by is not null
      and last_verified_at is not null
    )
  )
);

create index if not exists india_ulb_district_recon_status_state_idx
  on public.india_ulb_district_reconciliation (resolution_status, state_ut_id);

create index if not exists india_ulb_district_recon_district_idx
  on public.india_ulb_district_reconciliation (proposed_district_unit_id)
  where proposed_district_unit_id is not null;

create or replace function private.validate_ulb_district_reconciliation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_ulb_type text;
  v_ulb_state uuid;
  v_district_type text;
  v_district_state uuid;
begin
  select u.unit_type, u.state_ut_id
    into v_ulb_type, v_ulb_state
  from public.india_administrative_units u
  where u.id = new.ulb_unit_id;

  if v_ulb_type is distinct from 'urban_local_body' then
    raise exception 'Reconciliation target must be an urban local body';
  end if;

  if v_ulb_state is distinct from new.state_ut_id then
    raise exception 'ULB State/UT does not match reconciliation row';
  end if;

  if new.proposed_district_unit_id is not null then
    select d.unit_type, d.state_ut_id
      into v_district_type, v_district_state
    from public.india_administrative_units d
    where d.id = new.proposed_district_unit_id;

    if v_district_type is distinct from 'district' then
      raise exception 'Proposed parent must be a district unit';
    end if;

    if v_district_state is distinct from new.state_ut_id then
      raise exception 'ULB and proposed district must belong to the same State/UT';
    end if;
  end if;

  if new.resolution_status = 'verified' then
    if (select auth.uid()) is null then
      raise exception 'Authenticated reviewer required';
    end if;
    new.last_verified_by := (select auth.uid());
    new.last_verified_at := now();
  end if;

  new.updated_at := now();
  return new;
end;
$function$;

revoke all on function private.validate_ulb_district_reconciliation()
  from public, anon, authenticated;

drop trigger if exists validate_ulb_district_reconciliation
  on public.india_ulb_district_reconciliation;
create trigger validate_ulb_district_reconciliation
before insert or update on public.india_ulb_district_reconciliation
for each row execute function private.validate_ulb_district_reconciliation();

alter table public.india_ulb_district_reconciliation enable row level security;

revoke all privileges on table public.india_ulb_district_reconciliation
  from public, anon, authenticated;
grant select, insert, update on table public.india_ulb_district_reconciliation
  to authenticated;

drop policy if exists admin_coordinator_read_ulb_district_reconciliation
  on public.india_ulb_district_reconciliation;
create policy admin_coordinator_read_ulb_district_reconciliation
on public.india_ulb_district_reconciliation
for select to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid())
      and p.role in ('admin','coordinator')
  )
);

drop policy if exists admin_coordinator_insert_ulb_district_reconciliation
  on public.india_ulb_district_reconciliation;
create policy admin_coordinator_insert_ulb_district_reconciliation
on public.india_ulb_district_reconciliation
for insert to authenticated
with check (
  exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid())
      and p.role in ('admin','coordinator')
  )
);

drop policy if exists admin_coordinator_update_ulb_district_reconciliation
  on public.india_ulb_district_reconciliation;
create policy admin_coordinator_update_ulb_district_reconciliation
on public.india_ulb_district_reconciliation
for update to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid())
      and p.role in ('admin','coordinator')
  )
)
with check (
  exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid())
      and p.role in ('admin','coordinator')
  )
);

insert into public.india_ulb_district_reconciliation (
  ulb_unit_id, state_ut_id, source_system, source_vintage, resolution_status
)
select
  u.id, u.state_ut_id,
  coalesce(u.source_system, 'source system not recorded'),
  u.source_vintage,
  'unmapped'
from public.india_administrative_units u
where u.unit_type = 'urban_local_body'
  and u.state_ut_id is not null
on conflict (ulb_unit_id) do nothing;

comment on table public.india_ulb_district_reconciliation is
  'Admin/coordinator-only, evidence-backed queue for resolving ULB-to-district parent links. All initial rows are unmapped; no parent is inferred from a state label.';
comment on column public.india_ulb_district_reconciliation.proposed_district_unit_id is
  'Candidate district row; database trigger enforces unit_type=district and same State/UT.';
comment on column public.india_ulb_district_reconciliation.mapping_source_url is
  'Official or explicitly authorised source proving the ULB-to-district relationship.';
comment on function private.validate_ulb_district_reconciliation() is
  'Internal trigger validates ULB and district unit types, State/UT consistency and evidence requirements before a mapping can be marked verified.';
