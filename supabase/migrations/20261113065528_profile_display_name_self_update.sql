-- Authenticated users may edit only their own display name.
-- The column-level grant intentionally excludes role and department_id.
grant update (display_name)
on table public.profiles
to authenticated;

create policy "Users can update their own display name"
on public.profiles
for update
to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));
