# SAMANVAY Beta 0.2 — Acceptance and Recovery Plan

**Working branch:** `beta-0.2/recovery`  
**Baseline:** `main` at the time this branch was created  
**Release status:** In progress — not accepted

## Release principles

1. Preserve the existing SAMANVAY brand assets and visual identity. Never redraw or replace the approved logo without explicit approval.
2. Keep the four account classes distinct: Citizen, Department Officer, Coordinator, Administrator.
3. Authentication and authorization must be enforced by Supabase policies and trusted server-side checks. A client-side profile switch is not proof of authority.
4. Demonstration GIS features must be labelled **DEMO DATA** and must never be represented as verified utility records.
5. An empty verified underground-asset registry means **data unavailable**, not that the ground is utility-free.
6. Do not claim a feature is complete until it has been built and tested on an Android target.

## Workstreams and acceptance gates

### A. Recovery and build integrity
- [ ] Create a protected working branch from the accessible repository baseline.
- [ ] Keep the Flutter source and CI build inputs consistent.
- [ ] Run formatter, static analysis, and release APK build.
- [ ] Inspect APK package metadata, signature, and ZIP integrity.
- [ ] Record the exact commit and CI run used for the candidate APK.

### B. Authentication and account lifecycle
- [ ] Simple login and registration flows.
- [ ] Mobile-number registration/login with OTP using a configured Supabase phone provider.
- [ ] Email authentication retained as a supported option.
- [ ] Password reset/recovery flow.
- [ ] Explicit sign-out and expired-session handling.
- [ ] No OTP or password values logged or stored in application preferences.

### C. Role-based workspaces
- [ ] Citizen workspace.
- [ ] Department Officer workspace scoped to assigned department.
- [ ] Coordinator workspace for cross-department coordination.
- [ ] Administrator workspace for controlled platform administration.
- [ ] Server-side authorization and row-level security tests for each role.
- [ ] Demo account switching, if enabled, is isolated from production authority and visibly marked DEMO.

### D. GIS and underground visualization
- [ ] Public-facing map entry point available to Citizens and officials.
- [ ] Geographic navigation hierarchy: India → State → District → City → Ward, subject to available boundary data.
- [ ] Search, layer controls, legend, and clear data-source/freshness labels.
- [ ] Above-ground context and underground cross-section presentation.
- [ ] Water, sewer/drainage, electricity, telecom, gas, and other approved utility categories.
- [ ] Demo geometries visibly labelled DEMO DATA.
- [ ] Unknown/empty areas displayed as data unavailable, never as clear/safe.
- [ ] Operational use blocked until utility owner permission, geometry, CRS, positional accuracy, depth reference, source date, and verification are present.

### E. Citizen and departmental workflows
- [ ] Citizen excavation request submission and status tracking.
- [ ] Department review and action history.
- [ ] Coordinator cross-department workflow.
- [ ] Evidence attachment metadata and audit trail.
- [ ] Authorization tests prevent users from reading or changing another department's restricted records.

### F. Brand and usability
- [ ] Approved SAMANVAY logo used unchanged.
- [ ] Opening animation follows the approved design brief.
- [ ] Mobile-first, uncluttered login.
- [ ] Light/dark theme readability.
- [ ] No visible use of the obsolete role label “Requester”; use “Citizen”.

## Verified baseline findings

The inspected `app/main.dart` currently contains:
- Basic Supabase email/password authentication.
- A basic Citizen-style excavation request module.
- A MapPage that is only a placeholder.
- A profile screen that displays the current user and logs out.

The inspected source did not demonstrate:
- Mobile OTP authentication.
- Password recovery.
- Separate officer, coordinator, and administrator workspaces.
- A functional GIS map or underground cross-section.

A previous infrastructure audit recorded zero rows in `gis.underground_assets` and zero rows in `gis.asset_survey_evidence`. This plan therefore permits synthetic demonstration geometry only when clearly labelled; it does not treat synthetic geometry as a real utility registry.

## Completion rule

Beta 0.2 is **100% complete only when every applicable checkbox above is implemented, the Android release build succeeds, and the critical flows are verified on a device or emulator**. A source-code change or a green compilation alone is not sufficient.


## Beta 0.2 implementation update — 2026-11-13

### Implemented in `beta-0.2/recovery`
- Database-backed role routing: Citizen (`requester` in the existing database), Department Officer, Coordinator, and Administrator.
- Official workspaces query only the cases returned by existing Supabase RLS policies.
- Administrator account directory uses the existing protected `admin_user_directory` RPC.
- Administrator role changes call `admin_update_profile_role`; the UI prevents self-edit and the database enforces administrator checks, valid role values, department assignment, last-admin protection, audit logging, and notification.
- Registration offers Citizen, Department Officer, Coordinator, and Administrator account intent. Official roles are requests only; the profile remains Citizen until an administrator approves.
- Added `account_access_requests` with own-request and administrator-read RLS policies. Approval/rejection is performed by `admin_review_access_request`, which checks administrator identity, prevents self-review, delegates role assignment to the existing protected role RPC, and records audit/notification events.
- Added administrator-only `admin_access_request_directory` RPC for pending application review.
- Added Flutter CI type fix for the administrator directory loader.

### Live database deployment
The additive `account_access_requests` table, indexes, RLS policies, review RPC, and administrator directory RPC were applied to the connected Supabase project and verified by checking the table and function registrations. The same SQL is recorded in `supabase/migrations/20261113030000_account_access_requests.sql`.

### Verification still outstanding
- Latest commit requires a fresh successful analyzer + Android release build + artifact upload.
- Email confirmation, phone SMS delivery, OTP verification, password recovery deep link, official-access request submission, approval/rejection and post-approval role routing require device-level end-to-end tests.
- Existing production schema contains migrations not represented in the repository. Full migration-history reconciliation is still required before treating a clean database deployment as reproducible.
- Supabase advisor reports callable SECURITY DEFINER functions and disabled leaked-password protection. Reviewed role-management RPCs contain explicit administrator checks; the wider function set still requires a complete function-by-function security review. Do not blanket-revoke functions without confirming application dependencies.
- GIS remains a synthetic schematic. Satellite basemap, verified GIS sources, national/state/ward geospatial navigation and a true 3D view remain unimplemented.
- Approved logo and opening animation remain unverified against source assets.

**Release rule:** Beta 0.2 is not complete until all required checks above are either passed or explicitly deferred in the release scope, and the APK is installed and exercised on a real Android device.
