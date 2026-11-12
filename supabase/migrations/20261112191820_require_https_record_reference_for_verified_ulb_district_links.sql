alter table public.india_ulb_district_reconciliation
  drop constraint if exists india_ulb_district_verified_requires_evidence;

alter table public.india_ulb_district_reconciliation
  add constraint india_ulb_district_verified_requires_evidence check (
    resolution_status <> 'verified'
    or (
      proposed_district_unit_id is not null
      and nullif(btrim(mapping_source), '') is not null
      and mapping_source_url ~ '^https://[^[:space:]]+$'
      and nullif(btrim(mapping_source_reference), '') is not null
      and nullif(btrim(rationale), '') is not null
      and last_verified_by is not null
      and last_verified_at is not null
    )
  );

comment on constraint india_ulb_district_verified_requires_evidence
on public.india_ulb_district_reconciliation is
  'A verified ULB-to-district link requires a same-State/UT district, HTTPS source, source record reference, rationale and database-stamped reviewer/time.';
