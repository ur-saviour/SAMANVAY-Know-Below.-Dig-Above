-- SAMANVAY: India administrative hierarchy and LGD coverage
-- Applied to Supabase on 2026-11-06.
-- LGD bulk exports are generated on the official portal and require a CAPTCHA.
-- This migration creates a provenance-preserving import destination; it does not
-- fabricate district/ULB rows or bypass the source portal's CAPTCHA.

alter table public.india_data_coverage
drop constraint if exists india_data_coverage_data_domain_check;

alter table public.india_data_coverage
add constraint india_data_coverage_data_domain_check
check (data_domain = any (array[
  'groundwater','utility_gis','building_approvals','road_right_of_way',
  'water_supply','sewerage_wastewater','stormwater_drainage',
  'electricity_distribution','telecom_fibre','city_gas','administrative_directory'
]::text[]));

create table if not exists public.india_directory_import_batches (
  id uuid primary key default gen_random_uuid(),
  source_system text not null default 'Local Government Directory (LGD)',
  source_url text not null,
  jurisdiction_state_ut_id uuid references public.india_state_uts(id),
  unit_type text not null check (unit_type in (
    'district','sub_district','block','urban_local_body',
    'gram_panchayat','village','ward','traditional_local_body'
  )),
  source_updated_at date,
  original_file_name text,
  file_sha256 text,
  import_status text not null default 'awaiting_authorised_export'
    check (import_status in (
      'awaiting_authorised_export','uploaded','validated','imported','rejected'
    )),
  rows_received integer not null default 0 check (rows_received >= 0),
  rows_inserted integer not null default 0 check (rows_inserted >= 0),
  rows_rejected integer not null default 0 check (rows_rejected >= 0),
  notes text,
  imported_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

create table if not exists public.india_administrative_units (
  id uuid primary key default gen_random_uuid(),
  state_ut_id uuid not null references public.india_state_uts(id),
  parent_unit_id uuid references public.india_administrative_units(id),
  import_batch_id uuid references public.india_directory_import_batches(id),
  unit_type text not null check (unit_type in (
    'district','sub_district','block','urban_local_body',
    'gram_panchayat','village','ward','traditional_local_body'
  )),
  lgd_code text,
  name text not null,
  local_name text,
  source_system text not null default 'Local Government Directory (LGD)',
  source_url text not null default 'https://lgdirectory.gov.in/',
  source_updated_at date,
  verification_status text not null default 'imported_unverified'
    check (verification_status in (
      'imported_unverified','authority_verified','superseded','rejected'
    )),
  is_active boolean not null default true,
  valid_from date,
  valid_to date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (valid_to is null or valid_from is null or valid_to >= valid_from)
);

create unique index if not exists india_admin_units_source_code_uidx
  on public.india_administrative_units(source_system,lgd_code)
  where lgd_code is not null;
create index if not exists india_admin_units_state_type_idx
  on public.india_administrative_units(state_ut_id,unit_type,is_active);
create index if not exists india_admin_units_parent_idx
  on public.india_administrative_units(parent_unit_id);
create index if not exists india_directory_batches_status_idx
  on public.india_directory_import_batches(import_status,created_at desc);

alter table public.india_administrative_units enable row level security;
alter table public.india_directory_import_batches enable row level security;

drop policy if exists "Authenticated read India administrative units"
  on public.india_administrative_units;
create policy "Authenticated read India administrative units"
  on public.india_administrative_units for select to authenticated using (true);

drop policy if exists "Admins coordinators manage India administrative units"
  on public.india_administrative_units;
create policy "Admins coordinators manage India administrative units"
  on public.india_administrative_units for all to authenticated
  using (exists (
    select 1 from public.profiles p
    where p.id=(select auth.uid()) and p.role in ('admin','coordinator')
  ))
  with check (exists (
    select 1 from public.profiles p
    where p.id=(select auth.uid()) and p.role in ('admin','coordinator')
  ));

drop policy if exists "Admins coordinators read India directory batches"
  on public.india_directory_import_batches;
create policy "Admins coordinators read India directory batches"
  on public.india_directory_import_batches for select to authenticated
  using (exists (
    select 1 from public.profiles p
    where p.id=(select auth.uid()) and p.role in ('admin','coordinator')
  ));

drop policy if exists "Admins coordinators manage India directory batches"
  on public.india_directory_import_batches;
create policy "Admins coordinators manage India directory batches"
  on public.india_directory_import_batches for all to authenticated
  using (exists (
    select 1 from public.profiles p
    where p.id=(select auth.uid()) and p.role in ('admin','coordinator')
  ))
  with check (exists (
    select 1 from public.profiles p
    where p.id=(select auth.uid()) and p.role in ('admin','coordinator')
  ));

insert into public.india_data_coverage
  (state_ut_id,data_domain,responsible_authority,official_portal_url,
   national_source_url,coverage_status,data_granularity,
   operational_use_allowed,last_checked_at,notes)
select s.id,'administrative_directory',
  'Ministry of Panchayati Raj — Local Government Directory (LGD); State/UT Revenue and Local Government departments maintain jurisdictional records.',
  'https://lgdirectory.gov.in/','https://panchayat.gov.in/en/lgd/',
  'official_portal_verified_captcha_required_for_bulk_export',
  'State → District → Sub-district/Block → Urban Local Body / Panchayat → Ward / Village. LGD codes are the national linkage key.',
  false,now(),
  'Official LGD portal inspected on 2026-11-06. Public directory views exist, but bulk report generation requires CAPTCHA. State/UT and ULB records must be imported from an authority-generated report and checked against LGD codes.'
from public.india_state_uts s
on conflict (state_ut_id,data_domain) do update set
  responsible_authority=excluded.responsible_authority,
  official_portal_url=excluded.official_portal_url,
  national_source_url=excluded.national_source_url,
  coverage_status=excluded.coverage_status,
  data_granularity=excluded.data_granularity,
  operational_use_allowed=false,
  last_checked_at=now(),
  notes=excluded.notes;

insert into public.official_data_sources
  (source_key,agency,dataset_name,source_url,geography,data_theme,
   access_mode,integration_status,format,last_checked_at,notes)
values
  ('india_lgd_admin_hierarchy','Ministry of Panchayati Raj',
   'Local Government Directory (LGD) — States, Districts, Sub-districts, Blocks, Urban Local Bodies, Panchayats and Wards',
   'https://lgdirectory.gov.in/','India — all States and Union Territories',
   'Administrative boundary and local-government reference directory',
   'authority_export_required','awaiting_authority_data','PDF, HTML, XLS, ODT',now(),
   'The Ministry confirms LGD is the standard public directory and assigns unique LGD codes. Bulk report generation requires CAPTCHA. No bypass attempted. OGD Platform lists LGD district/local-body resources, but the local-body resource page states that its API does not exist. Import only an authority-generated report with provenance and report date.')
on conflict (source_key) do update set
  agency=excluded.agency,dataset_name=excluded.dataset_name,
  source_url=excluded.source_url,geography=excluded.geography,
  data_theme=excluded.data_theme,access_mode=excluded.access_mode,
  integration_status=excluded.integration_status,format=excluded.format,
  last_checked_at=excluded.last_checked_at,notes=excluded.notes;
