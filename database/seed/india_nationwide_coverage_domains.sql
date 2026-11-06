-- SAMANVAY nationwide infrastructure coverage domain expansion
-- Applied to the connected Supabase project on 2026-11-06.
-- Idempotent: re-running this script refreshes metadata without enabling operational use.

alter table public.india_data_coverage
drop constraint if exists india_data_coverage_data_domain_check;

alter table public.india_data_coverage
add constraint india_data_coverage_data_domain_check
check (data_domain = any (array[
  'groundwater',
  'utility_gis',
  'building_approvals',
  'road_right_of_way',
  'water_supply',
  'sewerage_wastewater',
  'stormwater_drainage',
  'electricity_distribution',
  'telecom_fibre',
  'city_gas'
]::text[]));

insert into public.india_data_coverage
  (state_ut_id,data_domain,responsible_authority,official_portal_url,national_source_url,
   coverage_status,data_granularity,operational_use_allowed,last_checked_at,notes)
select
  s.id,
  d.data_domain,
  d.responsible_authority,
  null,
  d.national_source_url,
  'national_authority_identified_state_level_register_pending',
  d.data_granularity,
  false,
  now(),
  d.notes
from public.india_state_uts s
cross join (values
  ('road_right_of_way',
   'Jurisdiction-dependent road owner: Ministry of Road Transport & Highways / NHAI / State PWD / Urban Local Body. The exact custodian must be confirmed for each road.',
   'https://morth.nic.in/',
   'Road ownership and right-of-way metadata, permitted-work references, road-cut permit status, project history and restoration status. Authority-certified records required.',
   'National road-sector portal identified; state, city and road-owner registers are not confirmed by this row. Public metadata only; not a work or excavation clearance.'),
  ('water_supply',
   'Urban technical coordination: MoHUA CPHEEO; rural drinking-water programme: Department of Drinking Water & Sanitation, Ministry of Jal Shakti. State water boards, PHEDs and ULBs remain asset custodians.',
   'https://jaljeevanmission.gov.in/',
   'Water-supply authority, service-area and project metadata, asset-owner register reference and as-built record availability. Any asset geometry remains within the authorised custodian workflow.',
   'National programme and technical guidance sources identified. State/ULB operator and dataset completeness still require direct confirmation.'),
  ('sewerage_wastewater',
   'Urban technical coordination: MoHUA CPHEEO; state sewerage boards, PHEDs and Urban Local Bodies are the relevant local custodians, depending on jurisdiction.',
   'https://www.mohua.gov.in/ministry/our-division/details/cpheeo-QDM1IzMtQWa',
   'Sewerage and wastewater authority, service-area and project metadata, asset-owner register reference and as-built record availability. Detailed network records require custodian-controlled validation.',
   'National technical authority identified; local ownership and actual as-built register availability are pending confirmation.'),
  ('stormwater_drainage',
   'Urban technical coordination: MoHUA CPHEEO; stormwater and drainage ownership usually rests with the relevant State agency or Urban Local Body.',
   'https://www.mohua.gov.in/ministry/our-division/details/cpheeo-QDM1IzMtQWa',
   'Drainage authority, catchment/service-area metadata, project and maintenance references, and as-built record availability. Detailed asset records remain owner-controlled.',
   'National technical guidance source identified. This is not a verified drainage inventory or flood-clearance record.'),
  ('electricity_distribution',
   'State Electricity Department / State DISCOM / transmission utility, as applicable; Central Electricity Authority provides national-sector information.',
   'https://cea.nic.in/',
   'Utility owner, service territory, permit and coordination metadata, and confirmation that current owner records were checked. Sensitive asset geometry is not exposed in this directory.',
   'National sector source identified; state utility owner and record availability require confirmation.'),
  ('telecom_fibre',
   'Department of Telecommunications provides national policy/regulatory context; licensed telecom service providers and infrastructure providers are the network custodians.',
   'https://dot.gov.in/',
   'Operator and service-area metadata, permit/coordination references and authority confirmation. Exact underground route, depth and asset-point information is not displayed.',
   'National regulator portal identified; local operator records require owner authorisation and verification.'),
  ('city_gas',
   'Petroleum and Natural Gas Regulatory Board provides the national regulatory framework; authorised City Gas Distribution entities are the local network custodians.',
   'https://pngrb.gov.in/',
   'Authorised operator, licensed service-area and permit/coordination metadata. Exact underground route, depth, valve and asset-point information is not displayed.',
   'National regulator portal identified; local operator records require owner authorisation and verification.')
) as d(data_domain,responsible_authority,national_source_url,data_granularity,notes)
on conflict (state_ut_id,data_domain) do update set
  responsible_authority=excluded.responsible_authority,
  official_portal_url=excluded.official_portal_url,
  national_source_url=excluded.national_source_url,
  coverage_status=excluded.coverage_status,
  data_granularity=excluded.data_granularity,
  operational_use_allowed=false,
  last_checked_at=now(),
  notes=excluded.notes;
