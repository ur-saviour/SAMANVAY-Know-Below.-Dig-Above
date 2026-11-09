# Joint-work proposal and coordination workflow

## Purpose

The joint-work workspace lets an authorised SAMANVAY coordinator propose a shared delivery window for two infrastructure cases. It records department-level responses, then allows an authorised coordinator or administrator to record a planning schedule or reject the proposal.

The workspace is linked from the Coordinated Works Calendar and is available to department officers, coordinators and administrators.

## Workflow

1. **Create proposal** — An administrator or coordinator selects two distinct cases, enters a reason and may add an indicative date window. Both cases must already have assigned departments, and the combined assignment set must include at least two distinct departments.
2. **Department response** — A response row is created for each distinct assigned department across both cases. A department officer associated with that department can accept or decline once and can add remarks.
3. **Coordinator decision** — A proposal reaches `ready_for_coordinator` only when every participating department has accepted. An administrator or coordinator can then record the shared schedule. The coordinator can reject an open proposal with remarks.
4. **Audit and notification** — Proposal creation, each response and final decisions are recorded in an append-only event table. Notifications are sent to participating department accounts and relevant platform operators.

## State model

- `pending_department_responses`: at least one participating department has not responded.
- `declined`: a participating department declined.
- `ready_for_coordinator`: every participating department accepted.
- `scheduled`: an administrator/coordinator recorded a valid start and end date.
- `rejected_by_coordinator`: an administrator/coordinator rejected the proposal.
- `withdrawn`: reserved terminal state for a future withdrawal flow.

An active-pair unique index prevents duplicate open/scheduled proposals for the same two cases. A new proposal may be created after a previous one reaches a terminal rejection/decline/withdrawal state.

## Access control

- Public/anonymous users have no access.
- Direct client-side insert/update/delete is revoked for all three workflow tables.
- Authenticated users can read only proposals for which they are the creator, an administrator/coordinator, or a participating department officer.
- Response and event records use the same proposal-participant visibility check.
- All writes occur through database RPCs that validate the authenticated profile role and department assignment.
- The RPCs use a pinned empty search path, fully qualified object names, and execute permissions are revoked from `PUBLIC` and `anon`.

## Important boundary

A recorded joint-work schedule is a planning coordination result only. It is **not** an excavation permit, utility-owner clearance, statutory approval, no-dig exemption, engineering determination or safety certification. Existing permits, department clearances, owner confirmation, authority rules and field verification remain separate requirements. No proximity heuristic or missing record is treated as proof of a safe or clear site.

## Files

- `app/joint_work_coordination_page.dart` — Flutter UI for proposal creation, department responses, scheduling and decision history.
- `app/coordinated_work_calendar_page.dart` — entry point from the works calendar.
- `supabase/migrations/20261110020000_add_joint_work_proposal_workflow.sql` — additive tables, participant RLS, event history and role-checked RPCs.
- `.github/workflows/build-apk.yml` and `.github/workflows/build-web.yml` — copy the new page into Android and web Flutter builds.

## Deployment and acceptance status

The implementation is committed to `feature/alpha-03-integrated-platform`. The connected Supabase migration operation returned `cannot execute CREATE TABLE in a read-only transaction`; therefore deployment of the new tables and RPCs is not confirmed. The acceptance matrix intentionally remains unchecked until the migration is applied and the workflow is runtime-tested with:
- an administrator/coordinator creating and finalising a proposal;
- every participating department accepting/declining;
- a department outside the proposal being unable to read it or respond;
- a requester/anonymous user being unable to read or write proposal records; and
- notifications and event history matching the decisions.
