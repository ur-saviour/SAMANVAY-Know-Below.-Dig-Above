-- Make repeated department assignment requests idempotent.
-- Preserve coordinator/admin authorization and the unique assignment constraint.

CREATE OR REPLACE FUNCTION public.assign_request_department(
  p_request_id uuid,
  p_department_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_role text;
  v_review_id uuid;
BEGIN
  SELECT p.role
    INTO v_role
  FROM public.profiles p
  WHERE p.id = (SELECT auth.uid());

  IF v_role IS NULL OR v_role NOT IN ('admin', 'coordinator') THEN
    RAISE EXCEPTION 'Only coordinators or administrators can assign departments';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.excavation_requests r
    WHERE r.id = p_request_id
  ) THEN
    RAISE EXCEPTION 'Request not found';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.departments d
    WHERE d.id = p_department_id
  ) THEN
    RAISE EXCEPTION 'Department not found';
  END IF;

  INSERT INTO public.request_department_reviews (
    request_id,
    department_id,
    assigned_by
  )
  VALUES (
    p_request_id,
    p_department_id,
    (SELECT auth.uid())
  )
  ON CONFLICT ON CONSTRAINT request_department_reviews_unique_assignment
  DO NOTHING
  RETURNING id INTO v_review_id;

  -- A repeated assignment is a successful no-op. Return the existing row.
  IF v_review_id IS NULL THEN
    SELECT review.id
      INTO v_review_id
    FROM public.request_department_reviews review
    WHERE review.request_id = p_request_id
      AND review.department_id = p_department_id;

    IF v_review_id IS NULL THEN
      RAISE EXCEPTION 'Department assignment could not be retrieved after conflict handling';
    END IF;
  END IF;

  RETURN v_review_id;
END;
$function$;
