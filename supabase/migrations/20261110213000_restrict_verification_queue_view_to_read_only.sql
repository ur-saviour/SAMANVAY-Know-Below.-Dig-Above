-- The verification queue is an intentionally privileged, read-only projection.
-- The view applies its own auth.uid()-based admin/coordinator predicate; do not
-- leave table-wide DML grants on it from broad default grants.
revoke all privileges on table public.utility_asset_verification_queue
  from public, anon, authenticated;

grant select on table public.utility_asset_verification_queue
  to authenticated;

grant all privileges on table public.utility_asset_verification_queue
  to service_role;
