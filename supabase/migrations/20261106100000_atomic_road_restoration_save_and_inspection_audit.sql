create or replace function public.save_road_restoration_record(
  p_request_id uuid,
  p_responsible_department_id uuid,
  p_road_surface_type text,
  p_restoration_status text,
  p_cut_length_m numeric,
  p_cut_width_m numeric,
  p_restored_length_m numeric,
  p_restored_width_m numeric,
  p_restoration_method text,
  p_planned_restore_date date,
  p_inspection_outcome text,
  p_compaction_verified boolean,
  p_drainage_clear boolean,
  p_surface_quality_notes text
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $function$
declare
  v_user_id uuid := (select auth.uid());
  v_previous_inspection text;
  v_record_id uuid;
  v_inspection_id uuid;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  select r.inspection_outcome into v_previous_inspection
  from public.road_restoration_records r
  where r.request_id = p_request_id
    and r.responsible_department_id = p_responsible_department_id
  for update;

  insert into public.road_restoration_records (
    request_id, responsible_department_id, road_surface_type,
    restoration_status, cut_length_m, cut_width_m, restored_length_m,
    restored_width_m, restoration_method, planned_restore_date,
    completed_at, inspection_outcome, compaction_verified, drainage_clear,
    surface_quality_notes, created_by, updated_by
  ) values (
    p_request_id, p_responsible_department_id, p_road_surface_type,
    p_restoration_status, p_cut_length_m, p_cut_width_m, p_restored_length_m,
    p_restored_width_m, p_restoration_method, p_planned_restore_date,
    case when p_restoration_status = 'accepted' then now() else null end,
    p_inspection_outcome, coalesce(p_compaction_verified, false),
    coalesce(p_drainage_clear, false), p_surface_quality_notes,
    v_user_id, v_user_id
  )
  on conflict (request_id, responsible_department_id)
  do update set
    road_surface_type = excluded.road_surface_type,
    restoration_status = excluded.restoration_status,
    cut_length_m = excluded.cut_length_m,
    cut_width_m = excluded.cut_width_m,
    restored_length_m = excluded.restored_length_m,
    restored_width_m = excluded.restored_width_m,
    restoration_method = excluded.restoration_method,
    planned_restore_date = excluded.planned_restore_date,
    completed_at = case
      when excluded.restoration_status = 'accepted'
        then coalesce(public.road_restoration_records.completed_at, now())
      else null
    end,
    inspection_outcome = excluded.inspection_outcome,
    compaction_verified = excluded.compaction_verified,
    drainage_clear = excluded.drainage_clear,
    surface_quality_notes = excluded.surface_quality_notes,
    updated_by = v_user_id
  returning id into v_record_id;

  if p_inspection_outcome <> 'not_inspected'
     and p_inspection_outcome is distinct from v_previous_inspection then
    insert into public.case_inspections (
      request_id, inspection_type, outcome, notes, inspected_by
    ) values (
      p_request_id, 'post_work',
      case when p_inspection_outcome = 'accepted'
        then 'pass' else 'follow_up_required' end,
      coalesce(nullif(btrim(p_surface_quality_notes), ''),
        'Inspection outcome recorded through the road restoration workflow.'),
      v_user_id
    )
    returning id into v_inspection_id;
  end if;

  return jsonb_build_object(
    'record_id', v_record_id,
    'inspection_id', v_inspection_id,
    'inspection_event_created', v_inspection_id is not null
  );
end;
$function$;

revoke all on function public.save_road_restoration_record(
  uuid, uuid, text, text, numeric, numeric, numeric, numeric,
  text, date, text, boolean, boolean, text
) from public, anon;

grant execute on function public.save_road_restoration_record(
  uuid, uuid, text, text, numeric, numeric, numeric, numeric,
  text, date, text, boolean, boolean, text
) to authenticated;
