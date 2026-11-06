# Road-Cut Permit Compliance & Restoration Deadlines

## Purpose

This feature gives authorised staff a traceable register for road-cut permit and approval references, issuing authorities, validity windows, work dates, road-safety checks, utility-owner clearance and restoration deadlines. It complements the road-restoration quality board; it does not determine whether a permit is legally required or replace the competent road authority.

## Workflow

1. An authorised department officer, coordinator or administrator links a permit record to an infrastructure case and responsible department.
2. The officer records the permit status, reference, issuing authority, validity dates and restoration deadline. If a permit is not required, the reason must be recorded.
3. The officer records work-start and completion dates and confirms traffic-management, utility-clearance and road-safety arrangements.
4. The compliance view calculates a current state: awaiting permit, active, expired, suspended, revoked, outside the permit window, restoration due soon, restoration overdue, not required or closed.
5. A permit can be closed only after work completion is recorded and the linked road-restoration record has an accepted inspection, verified compaction/surface preparation, clear drainage and completion timestamp.

## Database implementation

- Table: `public.road_cut_permit_records`.
- Compliance view: `public.road_cut_permit_compliance`, configured with `security_invoker = true` so underlying row-level security remains in force.
- Unique record per case and responsible department.
- Check constraints validate status values, permit reference/authority/validity requirements, date ordering and documented exemption reasons.
- Indexes support deadline and case lookups.
- RLS allows requesters to read records attached to their own cases; department officers can read/create/update only records for their assigned department and assigned cases; coordinators and administrators can oversee records across departments.
- Anonymous access is revoked. Authenticated users receive only SELECT, INSERT and UPDATE privileges. No delete policy is provided.

## Application integration

The staff operations dashboard now contains a permit-compliance board. It supports registering and updating permit records, displaying the computed compliance state, and showing restoration deadlines and permit expiry. The view calculates deadline state at query time; proactive scheduled push notifications are not part of this version.

## Validation and data status

- Supabase confirms the table exists, RLS is enabled, three policies are present, the compliance view exists with security-invoker semantics, and authenticated table privileges are present while anon privileges are absent.
- A transaction-only QA test inserted a temporary pending record, checked the awaiting-permit state, verified that an issued permit without its required fields is rejected, and verified that permit closure is rejected without accepted restoration evidence. The test transaction was rolled back.
- The live permit table currently contains zero records. This is expected until authorised staff enter real permit and deadline data.
- The app records evidence entered by staff; it does not invent permit numbers, approval status, road authority decisions or statutory deadlines.

## Operational dependencies

Before rollout, the relevant road-owning authority must define which works require permits, the accepted permit evidence, applicable work windows, restoration deadlines, inspection requirements and authorised sign-off roles. Deadline values must be sourced from the actual permit or authority instruction, not assumed by the application.
