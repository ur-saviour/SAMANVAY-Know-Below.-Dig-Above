-- Rollback-only end-to-end regression for SAMANVAY official access requests.
-- Exercises authenticated RLS submission, the Administrator queue/review RPCs,
-- profile role assignment, audit rows and user notifications.
-- Requires three existing Citizen profiles, one Administrator and Water Supply.
-- No test request, role promotion or notification is retained.

BEGIN;
SELECT set_config('samanvay.test.citizen_one',
  (SELECT id::text FROM public.profiles WHERE role='requester' ORDER BY created_at LIMIT 1),true);
SELECT set_config('samanvay.test.citizen_two',
  (SELECT id::text FROM public.profiles WHERE role='requester' ORDER BY created_at OFFSET 1 LIMIT 1),true);
SELECT set_config('samanvay.test.citizen_three',
  (SELECT id::text FROM public.profiles WHERE role='requester' ORDER BY created_at OFFSET 2 LIMIT 1),true);
SELECT set_config('samanvay.test.admin',
  (SELECT id::text FROM public.profiles WHERE role='admin' LIMIT 1),true);
SELECT set_config('samanvay.test.department',
  (SELECT id::text FROM public.departments WHERE name='Water Supply' LIMIT 1),true);
SET LOCAL ROLE authenticated;

DO $samanvay_access_request_workflow$
DECLARE
  citizen_one uuid := current_setting('samanvay.test.citizen_one')::uuid;
  citizen_two uuid := current_setting('samanvay.test.citizen_two')::uuid;
  citizen_three uuid := current_setting('samanvay.test.citizen_three')::uuid;
  admin_id uuid := current_setting('samanvay.test.admin')::uuid;
  water_supply_id uuid := current_setting('samanvay.test.department')::uuid;
  coordinator_request_id uuid;
  officer_request_id uuid;
  admin_request_id uuid;
  queue_count integer;
  pending_count integer;
  role_one text;
  role_two text;
  role_three text;
  department_two uuid;
  status_one text;
  status_two text;
  status_three text;
  audit_count integer;
  notification_count integer;
BEGIN
  IF citizen_one IS NULL OR citizen_two IS NULL OR citizen_three IS NULL
     OR admin_id IS NULL OR water_supply_id IS NULL THEN
    RAISE EXCEPTION 'TEST INCONCLUSIVE: three Citizens, one Administrator and Water Supply are required';
  END IF;

  PERFORM set_config('request.jwt.claim.sub',citizen_one::text,true);
  PERFORM set_config('request.jwt.claim.role','authenticated',true);
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',citizen_one,'role','authenticated')::text,true);
  INSERT INTO public.account_access_requests(user_id,requested_role,department_id,reason,status)
  VALUES(citizen_one,'coordinator',NULL,'Rollback-only test requesting Coordinator workspace access.','pending')
  RETURNING id INTO coordinator_request_id;

  PERFORM set_config('request.jwt.claim.sub',citizen_two::text,true);
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',citizen_two,'role','authenticated')::text,true);
  INSERT INTO public.account_access_requests(user_id,requested_role,department_id,reason,status)
  VALUES(citizen_two,'department',water_supply_id,'Rollback-only test requesting Water Supply Officer access.','pending')
  RETURNING id INTO officer_request_id;

  PERFORM set_config('request.jwt.claim.sub',citizen_three::text,true);
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',citizen_three,'role','authenticated')::text,true);
  INSERT INTO public.account_access_requests(user_id,requested_role,department_id,reason,status)
  VALUES(citizen_three,'admin',NULL,'Rollback-only test requesting Administrator workspace access.','pending')
  RETURNING id INTO admin_request_id;

  PERFORM set_config('request.jwt.claim.sub',admin_id::text,true);
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',admin_id,'role','authenticated')::text,true);
  SELECT count(*) INTO queue_count
  FROM public.admin_access_request_directory()
  WHERE request_id IN (coordinator_request_id,officer_request_id,admin_request_id);
  IF queue_count<>3 THEN RAISE EXCEPTION 'TEST FAILURE: Admin queue returned % of 3 test requests',queue_count; END IF;

  PERFORM public.admin_review_access_request(coordinator_request_id,'approve','Rollback-only access workflow regression test.');
  PERFORM public.admin_review_access_request(officer_request_id,'approve','Rollback-only access workflow regression test.');
  PERFORM public.admin_review_access_request(admin_request_id,'reject','Rollback-only access workflow regression test.');

  SELECT count(*) INTO pending_count FROM public.admin_access_request_directory()
    WHERE request_id IN (coordinator_request_id,officer_request_id,admin_request_id);
  IF pending_count<>0 THEN RAISE EXCEPTION 'TEST FAILURE: reviewed requests remain pending'; END IF;

  SELECT p.role INTO role_one FROM public.profiles p WHERE p.id=citizen_one;
  SELECT p.role,p.department_id INTO role_two,department_two FROM public.profiles p WHERE p.id=citizen_two;
  SELECT p.role INTO role_three FROM public.profiles p WHERE p.id=citizen_three;
  SELECT r.status INTO status_one FROM public.account_access_requests r WHERE r.id=coordinator_request_id;
  SELECT r.status INTO status_two FROM public.account_access_requests r WHERE r.id=officer_request_id;
  SELECT r.status INTO status_three FROM public.account_access_requests r WHERE r.id=admin_request_id;

  IF role_one<>'coordinator' OR status_one<>'approved' THEN
    RAISE EXCEPTION 'TEST FAILURE: Coordinator approval did not update role and status';
  END IF;
  IF role_two<>'department' OR department_two<>water_supply_id OR status_two<>'approved' THEN
    RAISE EXCEPTION 'TEST FAILURE: Officer approval did not set role, department and status';
  END IF;
  IF role_three<>'requester' OR status_three<>'rejected' THEN
    RAISE EXCEPTION 'TEST FAILURE: rejection changed Citizen role or failed to mark request rejected';
  END IF;

  SELECT count(*) INTO audit_count FROM public.admin_audit_events a
  WHERE a.event_type IN ('account_access_request_approve','account_access_request_reject')
    AND a.details->>'request_id' IN (coordinator_request_id::text,officer_request_id::text,admin_request_id::text);
  IF audit_count<>3 THEN RAISE EXCEPTION 'TEST FAILURE: expected 3 audit events, got %',audit_count; END IF;

  PERFORM set_config('request.jwt.claim.sub',citizen_one::text,true);
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',citizen_one,'role','authenticated')::text,true);
  SELECT count(*) INTO notification_count FROM public.user_notifications n
  WHERE n.recipient_id=citizen_one AND n.data->>'request_id'=coordinator_request_id::text AND n.data->>'decision'='approve';
  IF notification_count<>1 THEN RAISE EXCEPTION 'TEST FAILURE: Coordinator applicant notification missing'; END IF;

  PERFORM set_config('request.jwt.claim.sub',citizen_two::text,true);
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',citizen_two,'role','authenticated')::text,true);
  SELECT count(*) INTO notification_count FROM public.user_notifications n
  WHERE n.recipient_id=citizen_two AND n.data->>'request_id'=officer_request_id::text AND n.data->>'decision'='approve';
  IF notification_count<>1 THEN RAISE EXCEPTION 'TEST FAILURE: Officer applicant notification missing'; END IF;

  PERFORM set_config('request.jwt.claim.sub',citizen_three::text,true);
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',citizen_three,'role','authenticated')::text,true);
  SELECT count(*) INTO notification_count FROM public.user_notifications n
  WHERE n.recipient_id=citizen_three AND n.data->>'request_id'=admin_request_id::text AND n.data->>'decision'='reject';
  IF notification_count<>1 THEN RAISE EXCEPTION 'TEST FAILURE: rejected applicant notification missing'; END IF;

  RAISE NOTICE 'PASS: 3 authenticated submissions, 3 Admin queue results, 2 approvals, 1 rejection, 3 audit events and 3 personal notifications.';
END
$samanvay_access_request_workflow$;
ROLLBACK;
