revoke all on public.building_compliance_inspections from anon, authenticated;
grant select, insert on public.building_compliance_inspections to authenticated;
create index if not exists building_compliance_created_by_idx
  on public.building_compliance_inspections (created_by);