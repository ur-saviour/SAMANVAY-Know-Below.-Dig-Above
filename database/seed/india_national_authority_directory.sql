-- SAMANVAY national authority directory
-- Applied to the connected Supabase project on 2026-11-06.
-- National bodies are source/coordination references, not substitutes for
-- the State/UT, local body, DISCOM, utility operator or asset owner.

create table if not exists public.india_national_authority_directory (
  id uuid primary key default gen_random_uuid(),
  authority_key text not null unique,
  authority_name text not null,
  authority_level text not null check (authority_level = any(array[
    'central_ministry','central_department','national_programme','national_regulator','national_directory','national_technical_body'
  ]::text[])),
  responsibility text not null,
  domain_tags text[] not null default '{}',
  official_portal_url text not null,
  source_reference_url text not null,
  local_custodian_required boolean not null default true,
  verification_status text not null default 'official_portal_confirmed'
    check (verification_status = any(array['official_portal_confirmed','scope_review_required','inactive']::text[])),
  last_checked_at timestamptz not null default now(),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists india_national_authority_domains_gin
  on public.india_national_authority_directory using gin(domain_tags);

alter table public.india_national_authority_directory enable row level security;

drop policy if exists "Authenticated read national authority directory" on public.india_national_authority_directory;
create policy "Authenticated read national authority directory"
  on public.india_national_authority_directory for select to authenticated using (true);

drop policy if exists "Admins coordinators manage national authority directory" on public.india_national_authority_directory;
create policy "Admins coordinators manage national authority directory"
  on public.india_national_authority_directory for all to authenticated
  using (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role in ('admin','coordinator')))
  with check (exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role in ('admin','coordinator')));

insert into public.india_national_authority_directory
(authority_key,authority_name,authority_level,responsibility,domain_tags,official_portal_url,source_reference_url,local_custodian_required,verification_status,notes)
values
('mopr_lgd','Ministry of Panchayati Raj — Local Government Directory','central_ministry',
 'Maintains the standard administrative directory and unique LGD codes for revenue entities and local-government bodies.',
 array['administrative_directory'],'https://panchayat.gov.in/en/lgd/','https://panchayat.gov.in/en/lgd/',true,'official_portal_confirmed',
 'LGD codes are the interoperability key for State, district, sub-district, block, ULB, panchayat, village and ward references. State-maintained records and the latest export must still be reconciled.'),
('nic_igod','Integrated Government Online Directory (IGOD) — NIC','national_directory',
 'Provides State/UT district indexes and official government website discovery.',
 array['administrative_directory','building_approvals'],'https://igod.gov.in/sg/district/states','https://igod.gov.in/sg/district/states',true,'official_portal_confirmed',
 'Use for district administration and government-portal discovery; not a replacement for LGD codes or authoritative approval registers.'),
('mohua_cpheeo','Ministry of Housing and Urban Affairs — CPHEEO','central_ministry',
 'National technical guidance and coordination for urban water supply, sewerage and stormwater drainage.',
 array['water_supply','sewerage_wastewater','stormwater_drainage','building_approvals'],
 'https://www.mohua.gov.in/ministry/our-division/details/cpheeo-QDM1IzMtQWa','https://www.mohua.gov.in/ministry/our-division/details/cpheeo-QDM1IzMtQWa',true,'official_portal_confirmed',
 'CPHEEO is a national technical authority; State agencies, water/sewerage boards and ULBs remain the local asset and approval custodians.'),
('ddws_jjm','Department of Drinking Water and Sanitation — Jal Jeevan Mission','national_programme',
 'National programme and monitoring context for rural drinking-water service delivery.',
 array['water_supply'],'https://jaljeevanmission.gov.in/','https://jaljeevanmission.gov.in/',true,'official_portal_confirmed',
 'Programme dashboards and service coverage are not a substitute for the local operator''s current asset register or as-built records.'),
('cgwb','Central Ground Water Board','national_technical_body',
 'National groundwater assessment, monitoring and technical information.',
 array['groundwater'],'https://cgwb.gov.in/','https://cgwb.gov.in/',true,'official_portal_confirmed',
 'Groundwater assessments and monitoring records must retain assessment year, station/district attribution and source provenance; State groundwater regulators may have separate permitting roles.'),
('morth','Ministry of Road Transport and Highways','central_ministry',
 'National road-sector policy, standards and national-highway administration context.',
 array['road_right_of_way'],'https://morth.nic.in/','https://morth.nic.in/',true,'official_portal_confirmed',
 'Actual road ownership, right-of-way permission and road-cut approvals must be confirmed with NHAI, State PWD, municipal road owner or other competent road authority.'),
('cea','Central Electricity Authority','national_technical_body',
 'National electricity-sector technical and planning information.',
 array['electricity_distribution'],'https://cea.nic.in/','https://cea.nic.in/',true,'official_portal_confirmed',
 'Distribution assets and permissions are controlled by the relevant State DISCOM, electricity department or transmission utility.'),
('dot','Department of Telecommunications','central_department',
 'National telecommunications policy and regulatory-administration context.',
 array['telecom_fibre'],'https://dot.gov.in/','https://dot.gov.in/',true,'official_portal_confirmed',
 'The licensed telecom service provider or infrastructure provider is the relevant local network custodian; no exact route information is stored in this directory.'),
('pngrb','Petroleum and Natural Gas Regulatory Board','national_regulator',
 'Regulatory framework for authorised city-gas distribution entities and related downstream gas infrastructure.',
 array['city_gas'],'https://pngrb.gov.in/','https://pngrb.gov.in/',true,'official_portal_confirmed',
 'The authorised City Gas Distribution entity is the local network custodian. Regulatory references do not constitute excavation clearance.')
on conflict (authority_key) do update set
 authority_name=excluded.authority_name,authority_level=excluded.authority_level,
 responsibility=excluded.responsibility,domain_tags=excluded.domain_tags,
 official_portal_url=excluded.official_portal_url,source_reference_url=excluded.source_reference_url,
 local_custodian_required=excluded.local_custodian_required,
 verification_status=excluded.verification_status,last_checked_at=now(),
 notes=excluded.notes,updated_at=now();
