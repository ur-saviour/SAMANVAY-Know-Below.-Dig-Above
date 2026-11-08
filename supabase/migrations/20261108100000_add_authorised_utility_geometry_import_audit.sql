-- Metadata-only audit trail for owner-authorised underground geometry imports.
-- Exact geometry remains stored in gis.underground_assets under owner-department controls.
-- Import submissions are recorded as pending review and never become operational automatically.

create table if not exists public.utility_geometry_import_runs (
  id uuid primary key default gen_random_uuid(),
  owner_department_id uuid not null references public.departments(id),
  requested_by uuid not null references public.profiles(id),
  source_title text not null check (length(btrim(source_title)) between 3 and 200),
  source_organisation text not null check (length(btrim(source_organisation)) between 3 and 200),
  source_type text not null check (source_type in ('utility_owner','field_survey','as_built_drawing')),
  authorization_reference text not null check (length(btrim(authorization_reference)) between 6 and 200),
  data_sharing_basis text not null check (length(btrim(data_sharing_basis)) between 10 and 1000),
  source_url text null check (source_url is null or source_url ~* '^https://'),
  declared_srid integer not null check (declared_srid = 4326),
  payload_sha256 text not null check (payload_sha256 ~ '^[0-9a-f]{64}$'),
  received_features integer not null default 0 check (received_features between 0 and 500),
  imported_features integer not null default 0 check (imported_features between 0 and 500),
  rejected_features integer not null default 0 check (rejected_features between 0 and 500),
  status text not null default 'importing'
    check (status in ('importing','imported_pending_review','partially_imported','failed')),
  error_summary text null check (error_summary is null or length(error_summary) <= 500),
  created_at timestamptz not null default now(),
  completed_at timestamptz null,
  constraint utility_geometry_import_counts_valid
    check (imported_features + rejected_features <= received_features)
);

comment on table public.utility_geometry_import_runs is
  'Metadata-only audit log for owner-authorised underground geometry submissions. Contains no geometry. Records are service-role managed; every imported asset remains unverified pending independent review.';

create index if not exists utility_geometry_import_runs_department_created_idx
  on public.utility_geometry_import_runs(owner_department_id, created_at desc);
create index if not exists utility_geometry_import_runs_requester_created_idx
  on public.utility_geometry_import_runs(requested_by, created_at desc);

alter table public.utility_geometry_import_runs enable row level security;
revoke all on table public.utility_geometry_import_runs from public, anon, authenticated;
grant select, insert, update on table public.utility_geometry_import_runs to service_role;
