create index if not exists admin_audit_events_actor_id_idx
  on public.admin_audit_events(actor_id);
create index if not exists admin_audit_events_target_user_id_idx
  on public.admin_audit_events(target_user_id);
create index if not exists case_ai_assessments_reviewed_by_idx
  on public.case_ai_assessments(reviewed_by);
create index if not exists case_attachments_uploaded_by_idx
  on public.case_attachments(uploaded_by);
create index if not exists case_coordination_checks_checked_by_idx
  on public.case_coordination_checks(checked_by);
create index if not exists case_inspections_inspected_by_idx
  on public.case_inspections(inspected_by);
create index if not exists case_messages_sender_id_idx
  on public.case_messages(sender_id);
create index if not exists user_notifications_request_id_idx
  on public.user_notifications(request_id);
