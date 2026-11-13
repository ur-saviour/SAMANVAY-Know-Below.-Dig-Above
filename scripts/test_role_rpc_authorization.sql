-- Role-specific RPC authorization regression test for SAMANVAY.
-- Run with a database role allowed to inspect profiles and execute protected RPCs.
-- Simulates request.jwt.claim.* for each existing role fixture in one transaction.
-- Expected denials occur before writes; the Administrator path is read-only.

DO $samanvay_role_rpc_tests$
DECLARE
  citizen_id uuid;
  officer_id uuid;
  coordinator_id uuid;
  administrator_id uuid;
  admin_visible_users integer := 0;
BEGIN
  SELECT id INTO citizen_id FROM public.profiles WHERE role='requester' ORDER BY created_at LIMIT 1;
  SELECT id INTO officer_id FROM public.profiles WHERE role='department' ORDER BY created_at LIMIT 1;
  SELECT id INTO coordinator_id FROM public.profiles WHERE role='coordinator' ORDER BY created_at LIMIT 1;
  SELECT id INTO administrator_id FROM public.profiles WHERE role='admin' ORDER BY created_at LIMIT 1;

  IF citizen_id IS NULL OR officer_id IS NULL OR coordinator_id IS NULL OR administrator_id IS NULL THEN
    RAISE EXCEPTION 'TEST INCONCLUSIVE: all four role fixtures are required';
  END IF;

  -- Citizen: six privileged operations must be denied.
  PERFORM set_config('request.jwt.claim.sub',citizen_id::text,true);
  PERFORM set_config('request.jwt.claim.role','authenticated',true);
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',citizen_id,'role','authenticated')::text,true);

  BEGIN PERFORM public.admin_user_directory();
    RAISE EXCEPTION 'TEST FAILURE: Citizen accessed admin_user_directory';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM='TEST FAILURE: Citizen accessed admin_user_directory' THEN RAISE;
    ELSIF SQLERRM<>'Administrator access required' THEN RAISE EXCEPTION 'Unexpected Citizen admin directory result: %',SQLERRM; END IF;
  END;
  BEGIN PERFORM public.admin_create_department('Citizen denial test',NULL);
    RAISE EXCEPTION 'TEST FAILURE: Citizen accessed admin_create_department';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM='TEST FAILURE: Citizen accessed admin_create_department' THEN RAISE;
    ELSIF SQLERRM<>'Administrator access required' THEN RAISE EXCEPTION 'Unexpected Citizen create department result: %',SQLERRM; END IF;
  END;
  BEGIN PERFORM public.admin_update_profile_role(citizen_id,'admin',NULL);
    RAISE EXCEPTION 'TEST FAILURE: Citizen accessed admin_update_profile_role';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM='TEST FAILURE: Citizen accessed admin_update_profile_role' THEN RAISE;
    ELSIF SQLERRM<>'Administrator access required' THEN RAISE EXCEPTION 'Unexpected Citizen role update result: %',SQLERRM; END IF;
  END;
  BEGIN PERFORM public.assign_request_department(gen_random_uuid(),gen_random_uuid());
    RAISE EXCEPTION 'TEST FAILURE: Citizen assigned a department';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM='TEST FAILURE: Citizen assigned a department' THEN RAISE;
    ELSIF SQLERRM<>'Only coordinators or administrators can assign departments' THEN RAISE EXCEPTION 'Unexpected Citizen assignment result: %',SQLERRM; END IF;
  END;
  BEGIN PERFORM public.change_request_status(gen_random_uuid(),'completed',NULL);
    RAISE EXCEPTION 'TEST FAILURE: Citizen changed request status';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM='TEST FAILURE: Citizen changed request status' THEN RAISE;
    ELSIF SQLERRM<>'Only coordinators or administrators can change overall request status' THEN RAISE EXCEPTION 'Unexpected Citizen status result: %',SQLERRM; END IF;
  END;
  BEGIN PERFORM public.submit_department_review(gen_random_uuid(),'approved',NULL);
    RAISE EXCEPTION 'TEST FAILURE: Citizen submitted a department review';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM='TEST FAILURE: Citizen submitted a department review' THEN RAISE;
    ELSIF SQLERRM<>'Only department officers can submit departmental reviews' THEN RAISE EXCEPTION 'Unexpected Citizen review result: %',SQLERRM; END IF;
  END;

  -- Department Officer: coordinator/admin RPCs must be denied.
  PERFORM set_config('request.jwt.claim.sub',officer_id::text,true);
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',officer_id,'role','authenticated')::text,true);
  BEGIN PERFORM public.admin_user_directory();
    RAISE EXCEPTION 'TEST FAILURE: Officer accessed admin_user_directory';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM='TEST FAILURE: Officer accessed admin_user_directory' THEN RAISE;
    ELSIF SQLERRM<>'Administrator access required' THEN RAISE EXCEPTION 'Unexpected Officer admin result: %',SQLERRM; END IF;
  END;
  BEGIN PERFORM public.assign_request_department(gen_random_uuid(),gen_random_uuid());
    RAISE EXCEPTION 'TEST FAILURE: Officer assigned a department';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM='TEST FAILURE: Officer assigned a department' THEN RAISE;
    ELSIF SQLERRM<>'Only coordinators or administrators can assign departments' THEN RAISE EXCEPTION 'Unexpected Officer assignment result: %',SQLERRM; END IF;
  END;
  BEGIN PERFORM public.change_request_status(gen_random_uuid(),'completed',NULL);
    RAISE EXCEPTION 'TEST FAILURE: Officer changed overall request status';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM='TEST FAILURE: Officer changed overall request status' THEN RAISE;
    ELSIF SQLERRM<>'Only coordinators or administrators can change overall request status' THEN RAISE EXCEPTION 'Unexpected Officer status result: %',SQLERRM; END IF;
  END;

  -- Coordinator: coordination role does not grant administrator privileges.
  PERFORM set_config('request.jwt.claim.sub',coordinator_id::text,true);
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',coordinator_id,'role','authenticated')::text,true);
  BEGIN PERFORM public.admin_user_directory();
    RAISE EXCEPTION 'TEST FAILURE: Coordinator accessed admin_user_directory';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM='TEST FAILURE: Coordinator accessed admin_user_directory' THEN RAISE;
    ELSIF SQLERRM<>'Administrator access required' THEN RAISE EXCEPTION 'Unexpected Coordinator admin result: %',SQLERRM; END IF;
  END;
  BEGIN PERFORM public.admin_create_department('Coordinator denial test',NULL);
    RAISE EXCEPTION 'TEST FAILURE: Coordinator accessed admin_create_department';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM='TEST FAILURE: Coordinator accessed admin_create_department' THEN RAISE;
    ELSIF SQLERRM<>'Administrator access required' THEN RAISE EXCEPTION 'Unexpected Coordinator create department result: %',SQLERRM; END IF;
  END;
  BEGIN PERFORM public.admin_update_profile_role(citizen_id,'admin',NULL);
    RAISE EXCEPTION 'TEST FAILURE: Coordinator accessed admin_update_profile_role';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM='TEST FAILURE: Coordinator accessed admin_update_profile_role' THEN RAISE;
    ELSIF SQLERRM<>'Administrator access required' THEN RAISE EXCEPTION 'Unexpected Coordinator role update result: %',SQLERRM; END IF;
  END;

  -- Administrator: positive, read-only directory path.
  PERFORM set_config('request.jwt.claim.sub',administrator_id::text,true);
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',administrator_id,'role','authenticated')::text,true);
  SELECT count(*) INTO admin_visible_users FROM public.admin_user_directory();
  IF admin_visible_users=0 THEN RAISE EXCEPTION 'TEST FAILURE: Administrator could not read the account directory'; END IF;

  RAISE NOTICE 'PASS: Citizen denied 6 protected RPCs; Officer denied 3; Coordinator denied 3; Administrator read-only directory path passed.';
END
$samanvay_role_rpc_tests$;
