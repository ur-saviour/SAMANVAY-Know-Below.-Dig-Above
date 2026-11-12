create table if not exists public.india_district_boundary_reference (
  id uuid primary key default gen_random_uuid(),
  administrative_unit_id uuid not null references public.india_administrative_units(id) on delete cascade,
  state_name text not null,
  district_name text not null,
  geom extensions.geometry(MultiPolygon, 4326) not null,
  source_system text not null,
  source_url text not null,
  source_license text not null,
  source_commit text not null,
  source_blob_sha text not null,
  source_vintage text,
  source_attributes jsonb not null default '{}'::jsonb,
  imported_at timestamptz not null default now(),
  constraint india_district_boundary_reference_geom_srid check (extensions.st_srid(geom) = 4326),
  constraint india_district_boundary_reference_geom_valid check (extensions.st_isvalid(geom))
);

create unique index if not exists india_district_boundary_reference_source_unit_uidx
  on public.india_district_boundary_reference (administrative_unit_id, source_blob_sha);

create index if not exists india_district_boundary_reference_geom_gix
  on public.india_district_boundary_reference using gist (geom);

create index if not exists india_district_boundary_reference_state_idx
  on public.india_district_boundary_reference (state_name, district_name);

alter table public.india_district_boundary_reference enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'india_district_boundary_reference'
      and policyname = 'Authenticated users can read India district reference boundaries'
  ) then
    create policy "Authenticated users can read India district reference boundaries"
      on public.india_district_boundary_reference
      for select to authenticated
      using (true);
  end if;
end $$;

revoke all on table public.india_district_boundary_reference from anon, authenticated;
grant select on table public.india_district_boundary_reference to authenticated;
grant all on table public.india_district_boundary_reference to service_role;

comment on table public.india_district_boundary_reference is
  'Third-party India district outline reference only. Historical multi-vintage source geometry, not statutory LGD boundary certification and not underground utility data. Source attribution and per-feature properties are retained.';
