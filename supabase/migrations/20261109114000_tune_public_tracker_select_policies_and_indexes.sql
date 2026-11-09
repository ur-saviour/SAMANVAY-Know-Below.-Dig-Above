-- Tighten the public tracker SELECT policy split and index its new foreign keys.
-- Anonymous readers evaluate only the publication predicate; signed-in users get
-- one SELECT policy that combines published access with their authorised draft scope.

drop policy if exists "Published SAMANVAY work notices are public"
  on public.public_excavation_notices;
drop policy if exists "Assigned staff can read draft notices"
  on public.public_excavation_notices;

create policy "Published SAMANVAY work notices are public"
  on public.public_excavation_notices for select to anon
  using (notice_status <> 'draft' and published_at is not null);

create policy "Published notices and assigned draft notices"
  on public.public_excavation_notices for select to authenticated
  using (
    (notice_status <> 'draft' and published_at is not null)
    or (
      notice_status = 'draft'
      and exists (
        select 1 from public.profiles p
        where p.id = (select auth.uid())
          and (p.role in ('admin', 'coordinator')
            or (p.role = 'department' and p.department_id is not null
                and p.department_id = responsible_department_id))
      )
    )
  );

create index if not exists public_excavation_notices_created_by_idx
  on public.public_excavation_notices(created_by);
create index if not exists public_excavation_notices_published_by_idx
  on public.public_excavation_notices(published_by);
create index if not exists public_excavation_notices_department_fk_idx
  on public.public_excavation_notices(responsible_department_id);
create index if not exists public_excavation_notice_events_created_by_idx
  on public.public_excavation_notice_events(created_by);
