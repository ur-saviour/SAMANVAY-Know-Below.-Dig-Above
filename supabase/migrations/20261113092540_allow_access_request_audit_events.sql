-- Allow the two audit event names emitted by admin_review_access_request.
-- Keep the audit event type allowlist strict and explicit.
ALTER TABLE public.admin_audit_events
  DROP CONSTRAINT IF EXISTS admin_audit_events_event_type_check;

ALTER TABLE public.admin_audit_events
  ADD CONSTRAINT admin_audit_events_event_type_check
  CHECK (
    event_type = ANY (
      ARRAY[
        'profile_role_changed',
        'department_created',
        'service_domain_route_changed',
        'account_access_request_approve',
        'account_access_request_reject'
      ]::text[]
    )
  );
