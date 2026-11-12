-- Phase 3 performance hardening: index the remaining foreign-key columns
-- identified by the live Supabase database advisor. All indexes are additive.
create index if not exists case_joint_work_events_actor_id_idx
  on public.case_joint_work_events(actor_id);

create index if not exists case_joint_work_proposals_finalised_by_idx
  on public.case_joint_work_proposals(finalised_by);
create index if not exists case_joint_work_proposals_primary_request_id_idx
  on public.case_joint_work_proposals(primary_request_id);
create index if not exists case_joint_work_proposals_related_request_id_idx
  on public.case_joint_work_proposals(related_request_id);

create index if not exists case_joint_work_responses_responded_by_idx
  on public.case_joint_work_responses(responded_by);

create index if not exists groundwater_station_observations_state_ut_id_idx
  on public.groundwater_station_observations(state_ut_id);

create index if not exists india_administrative_units_import_batch_id_idx
  on public.india_administrative_units(import_batch_id);

create index if not exists india_directory_import_batches_imported_by_idx
  on public.india_directory_import_batches(imported_by);
create index if not exists india_directory_import_batches_jurisdiction_state_ut_id_idx
  on public.india_directory_import_batches(jurisdiction_state_ut_id);

create index if not exists road_cut_permit_records_created_by_idx
  on public.road_cut_permit_records(created_by);
create index if not exists road_cut_permit_records_responsible_department_id_idx
  on public.road_cut_permit_records(responsible_department_id);
create index if not exists road_cut_permit_records_updated_by_idx
  on public.road_cut_permit_records(updated_by);

create index if not exists utility_asset_review_events_import_run_id_idx
  on public.utility_asset_review_events(import_run_id);
create index if not exists utility_asset_review_events_reviewed_by_idx
  on public.utility_asset_review_events(reviewed_by);
