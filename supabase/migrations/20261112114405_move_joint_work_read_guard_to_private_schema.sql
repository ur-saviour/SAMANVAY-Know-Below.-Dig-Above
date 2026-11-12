
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

alter function public.samanvay_can_view_joint_work_proposal(uuid)
  set schema private;

revoke all on function private.samanvay_can_view_joint_work_proposal(uuid)
  from public, anon;
grant execute on function private.samanvay_can_view_joint_work_proposal(uuid)
  to authenticated;

comment on function private.samanvay_can_view_joint_work_proposal(uuid) is
  'Internal RLS read guard for joint-work proposal participants; keep in a non-API schema.';
