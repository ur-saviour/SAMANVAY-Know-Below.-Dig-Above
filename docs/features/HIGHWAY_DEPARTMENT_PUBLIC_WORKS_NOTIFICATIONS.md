# Highway Department — Public Works notices and notifications

**Implementation branch:** `feature/highway-department-public-works-notifications`  
**Implementation date:** 12 November 2026  
**Status:** Backend migration applied; Flutter integration committed to the feature branch; CI verification pending.

## What changed

- Reused the existing `Roads & Highways` department record and renamed it to **Highway Department**. Its UUID remains unchanged, so existing department foreign keys and route mappings remain attached.
- The Highway Department uses the existing **Public works** operations board to create a sourced draft, review it, and publish it.
- The first publication of a Highway Department notice calls `public.publish_highway_work_notice`. The function validates the signed-in profile and department assignment, requires an official source reference, locks the draft row, publishes the notice, records a timeline event, and inserts in-app notifications in the same database transaction.
- Citizen recipients are profiles whose role is `requester` (displayed in the app as **Citizen**).
- Municipal recipients are department-officer profiles assigned to **Municipal Corporation**.
- The published notice is visible in the existing Citizen-facing **Public works** tab / public excavation tracker. Tapping a `public_work` notification opens that tracker.
- Notification rows use the existing `user_notifications` inbox with a new `public_work` type. They are not written directly by the mobile client.

## Publication safeguards

- Draft notices remain excluded from the public tracker.
- A source reference of at least three characters is required to publish.
- The RPC accepts only a notice owned by the Highway Department record.
- Department officers can publish only notices assigned to their own department. Coordinators and administrators may publish on behalf of Highway Department.
- The function records the exact number of Citizen and Municipal Corporation accounts notified.
- A second call against an already-published notice returns an idempotent result and does not create duplicate notifications.
- The function is executable only by authenticated users; anonymous execution is revoked.
- Other departments retain their existing publishing flow and are not silently included in this Highway-specific broadcast.

## Audience and delivery limitations

Notifications are **in-app inbox notifications**. This change does not claim OS-level push delivery, SMS, email, or a telecom gateway integration.

The current production profile snapshot has Citizen accounts, but no staff profile assigned to either Highway Department or Municipal Corporation. Therefore:
- Citizens will be notified when the first Highway Department notice is published.
- Municipal Corporation notifications will be delivered to all Municipal Corporation officer profiles that exist at publication time.
- The current profile schema has no city/ward jurisdiction field, so Municipal Corporation notifications are not yet geographically scoped. All registered Municipal Corporation officers are recipients.
- A real Highway Department staff account and a Municipal Corporation officer account are required for end-to-end role-based acceptance testing. No placeholder staff accounts were created.

## Current implementation verification

- Supabase migration applied successfully.
- Database verification confirms the Highway Department record exists with the prior Roads & Highways UUID.
- The `user_notifications_notification_type_check` constraint accepts `public_work`.
- `authenticated` has execute permission on the publish RPC; `anon` does not.
- Flutter CI is pending for this feature branch. No APK is described as built or signed until the Android release and package verification steps succeed.
