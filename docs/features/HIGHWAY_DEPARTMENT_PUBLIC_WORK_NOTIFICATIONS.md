# Highway Department public work notifications

**Status:** Database function applied; app changes prepared on the feature branch. Build and merge verification remain pending.

## Department registration

The existing `Roads & Highways` department row was renamed to **Highway Department** without changing its UUID. Existing foreign keys, service-domain routing and assigned records therefore continue to point at the same department.

## Publishing workflow

Highway Department staff can create a draft in the existing **Public works publishing & review** panel. A source reference is mandatory before publication. On the first publication, the app calls `public.publish_highway_work_notice`.

The database function:
- requires an authenticated profile;
- accepts only a Highway Department notice;
- permits the assigned Highway Department officer, a coordinator or an administrator;
- requires an unpublished draft and a source reference;
- publishes the notice, records the timeline event, and fans out in-app alerts in one database transaction;
- is idempotent: subsequent attempts do not send duplicate alerts.

A published Highway Department notice is visible in the existing Citizen-facing **Public works** tracker and is labelled as a Highway Department public notice.

## Notification audiences

The function sends `public_work` alerts to Citizen profiles (`role = requester`) and existing officers in municipal service departments: Municipal Corporation, Water Supply, Sewage and Drainage, Stormwater Management, Public Health Engineering, and Town Planning & Building Regulation.

This is an in-app notification stored in `public.user_notifications` and surfaced by SAMANVAY's notifications stream. Device push/SMS delivery is not claimed by this feature.

## Live verification

A transaction-scoped test used an existing administrator profile and a temporary draft, published it, attempted a second publication, then rolled the entire transaction back. Observed results:
- first publication: 3 Citizen alerts and 1 municipal-service department alert;
- second publication: `already_published = true`, 0 additional alerts;
- post-rollback check: no test notice, notification or publication remained.

Current account setup: 3 Citizen profiles, 1 municipal-service department officer profile (Water Supply), 0 Highway Department officer profiles and 0 Municipal Corporation officer profiles. The database recipient rule is ready for additional municipal-service staff accounts when they are provisioned and assigned to their departments.

## Scope limits

This feature does not invent highway projects or schedules. A notice must be entered by authorised SAMANVAY staff and carry an official source reference before it can be published. The published record remains a public-work notice; it is not a construction permit, utility clearance or traffic-police order.
