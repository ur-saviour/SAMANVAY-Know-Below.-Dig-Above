# Highway Department — Public works notices and notifications

**Implementation branch:** `feature/highway-public-works-notification-fanout-v2`  
**Implementation date:** 12 November 2026  
**Status:** Database publisher and recipient expansion applied to the connected Supabase project. Flutter changes are on this branch; CI verification is pending.

## What changed

- The existing `Roads & Highways` department record was renamed to **Highway Department** without changing its UUID, preserving existing foreign keys and service-domain routing.
- The Highway Department uses the existing **Public works** operations board to create a sourced draft and publish it.
- First publication calls `public.publish_highway_work_notice`. The database validates the signed-in profile and role, confirms the notice belongs to Highway Department, requires an official source reference, locks the draft, publishes it, records a timeline event and inserts notifications atomically.
- Published Highway notices appear in the Citizen-facing **Public works** tracker with a Highway Department label.
- Tapping a `public_work` alert opens the public works tracker.

## Notification audiences

The publish function sends in-app alerts to:
- all Citizen profiles (`role = requester`, shown as **Citizen** in the app); and
- existing officers assigned to these municipal service departments: **Municipal Corporation, Water Supply, Sewage and Drainage, Stormwater Management, Public Health Engineering, and Town Planning & Building Regulation**.

The current profile model does not store city or ward jurisdiction, so this is a profile-wide broadcast to those registered audiences, not a locality-targeted alert. Notifications are stored in `public.user_notifications` and shown in the in-app notifications stream. OS push, SMS and email are not claimed by this feature.

## Publication safeguards

- Drafts remain private and are not shown in the public tracker.
- A source reference of at least three characters is mandatory before publication.
- The function only accepts notices assigned to the Highway Department record.
- A Highway Department officer can publish only their own department's notices; coordinators and administrators can publish on its behalf.
- Anonymous execution is revoked; the function is executable by authenticated users only.
- The first publication and alert fan-out run in one transaction.
- Repeated publication is idempotent and does not send duplicate alerts.
- Other departments retain their existing publishing behaviour.

## Live account and test snapshot

Current connected-project profile counts:
- Citizens: **3**
- Highway Department officers: **0**
- Municipal Corporation officers: **0**
- Water Supply officers: **1**
- Other listed municipal service department officers: **0**

A transaction-scoped test created a temporary Highway draft as an administrator, published it, called publish a second time, and rolled the transaction back. The first call returned **3 Citizen alerts and 1 municipal-service department alert**. The second call returned `already_published = true` and zero additional alerts. A post-rollback query confirmed the test notice and notifications were not retained.

The live backend is ready to notify any additional eligible staff profiles when they are provisioned and assigned. No placeholder staff accounts were created. A Highway Department user account must be assigned before that role can sign in and use its own officer portal.

## Scope limits

A published notice is an authority-sourced public work announcement. It is not a road-cut permit, traffic-police order, underground-utility clearance or proof that an excavation is safe. No Highway project or schedule was fabricated as sample data.
