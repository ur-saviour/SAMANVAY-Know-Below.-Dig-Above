# SAMANVAY 1.0 — Professionalisation Progress Addendum

**Date:** 13 November 2026  
**Branch:** `feature/samanvay-1.0-professionalisation`  
**Verified source commit:** `0b1947d055e4893f9761bdc629218f5cd96bf299`  
**Build:** GitHub Actions run `43380232402` (#618), completed successfully.

This addendum records changes and validation completed after the baseline audit. It does not certify SAMANVAY 1.0 or claim physical-device acceptance.

## 1. Implemented changes

### Brand and opening lifecycle
- Restored the required tagline **Know Below. Dig Above.** in the app title, opening copy, GIS header and About copy.
- Retained the exact original `app/assets/brand/samanvay_logo.svg` asset; no artwork or logo path was substituted.
- Stopped the root ambient animation controller when the opening experience exits to the authenticated app.
- The original opening sequence was not comprehensively redesigned or device-timed in this increment.

### Theme contrast
- Replaced hard-coded white foreground text with the existing semantic theme foreground in the clearance workflow, live operations metrics, command-centre activity and public-works publishing/review panels.
- This is a targeted contrast correction, not a full screen-by-screen accessibility certification.

### Password recovery
- Added an AuthGate branch for `AuthChangeEvent.passwordRecovery` so a recovery-link session opens a dedicated password update screen rather than immediately opening the role dashboard.
- Added new-password and confirmation fields, minimum length validation, obscured input with a visibility control, loading/error handling and the Supabase `updateUser(UserAttributes(password: ...))` call.
- Unified the reset redirect to the existing `in.samanvay://login-callback/` app callback for the signed-out login reset and signed-in profile reset actions.
- Added source-contract regression checks for this recovery flow and the official tagline.

## 2. Android build and artifact verification

**Workflow:** [Build SAMANVAY Android APK — run 43380232402](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/43380232402)

Every configured step completed successfully:
- contract validation;
- Android package generation and validation;
- Flutter dependency installation;
- Dart analysis;
- release APK compilation;
- package, signature and alignment verification;
- artifact upload and Alpha 0.3 publication.

**Artifact:** `SAMANVAY-Alpha-0.3-APK`  
**Artifact ID:** `14016602193`  
**Artifact ZIP size:** 44,577,550 bytes  
**Artifact ZIP SHA-256:** `1ac6f9c86fc6b630aac2e608c503eed5addef8ecce30eb59790052dfdc84aa9c`

The artifact contains three ABI APKs: ARM64, armeabi-v7a and x86_64.

### Independent archive inspection

All three APK files passed ZIP CRC verification. The ARM64 APK contains DEX classes, Flutter runtime libraries and the expected application asset layout.

- ARM64 APK size: 33,583,252 bytes
- ARM64 APK SHA-256: `328aaa67da002117f401e3dca5a59c6dacf65033808b60d60c5e214343628efb`
- Logo inside the built ARM64 APK has Git blob SHA: `17c2db21509cfb59109cd413e8cb0f24d3f66524`
- Original source logo Git blob SHA: `17c2db21509cfb59109cd413e8cb0f24d3f66524`

The logo bytes in the built APK therefore match the original source asset exactly.

**Limit:** The build system still names and publishes this package as **Alpha 0.3**. No production signing-key migration or 1.0 versioning has occurred. No physical Android installation, launch, live SMS, deep-link, or signed-in password-recovery journey was performed.

## 3. Latest Supabase advisor snapshot

Project: `zhtotivedvkmclerdnlf`. Advisor snapshot observed on 13 November 2026.

| Advisor | Current result |
|---|---:|
| Authenticated-executable SECURITY DEFINER functions | 18 warnings |
| Leaked-password protection | Disabled warning |
| Unindexed foreign keys | 5 findings |
| Unused indexes | 81 findings |
| Multiple permissive policies | 14 findings |
| Duplicate indexes | 1 finding |
| Health advisor lints | 0 |

SECURITY DEFINER is not automatically a vulnerability. A read-only review of representative administrative, department-assignment, workflow and GIS functions found an empty search path and explicit actor/role checks in the inspected definitions. This is not yet a complete review of all 18 functions, their EXECUTE grants, or negative caller test cases. Do not bulk-revoke these functions: that could break legitimate workflows or fail to close an authorization gap.

Leaked-password protection remains disabled. Its Auth provider setting has not been changed.

## 4. Profile editing database constraint — migration applied

A narrowly scoped migration, `20261113065528_profile_display_name_self_update`, was successfully applied to the live Supabase project and is committed in `supabase/migrations/20261113065528_profile_display_name_self_update.sql`.

The migration grants column-level UPDATE on `public.profiles.display_name` only and adds an UPDATE RLS policy requiring `id = auth.uid()` for both `USING` and `WITH CHECK`. A follow-up privilege query confirmed:
- authenticated can UPDATE `display_name`;
- authenticated cannot UPDATE `role`;
- authenticated cannot UPDATE `department_id`;
- authenticated has no unrestricted table-level UPDATE;
- the self-row UPDATE policy is installed.

The Profile page now includes an Edit name action with 2-character minimum, 80-character maximum, database persistence and refreshed profile data. The build and static checks verify this implementation; a live authenticated save attempt by a test user is still required before marking profile editing end-to-end accepted.

## 5. Remaining release blockers

1. **Device acceptance:** install, first launch, upgrade, background/foreground, rotation/responsive layouts and restart on representative Android devices.
2. **Authentication E2E:** real provider SMS OTP for new and existing accounts; email recovery callback and actual password update; session expiry/logout; negative role/RLS tests for all four roles. Current account inventory previously recorded six users and no phone-confirmed accounts.
3. **Profile management:** introduce a safe, versioned display-name-only database migration and test it under authenticated RLS. Do not permit client-side role or department edits.
4. **GIS data:** the live operational underground asset and survey-evidence registries were empty in the latest recorded inventory. The public 250 m aggregate, owner-scoped verified geometry endpoint and synthetic cutaway must remain clearly distinguished. Obtain authorised surveyed assets before describing underground coverage as operational.
5. **Geographic reference data:** reconcile State/District/ULB/Ward records with authoritative data; retain explicit unmapped/unverified states.
6. **Security:** review all SECURITY DEFINER grants and caller checks; test denied calls; enable leaked-password protection after evaluating project plan and policy.
7. **Performance/accessibility:** measure real startup, frame pacing, memory, map/network loading and battery; test contrast, TalkBack, text scaling and touch targets.
8. **Build reproducibility:** commit a pinned Flutter dependency manifest and lockfile instead of resolving key packages at build time.
9. **Release signing:** replace the temporary debug signing certificate with a persistent owner-controlled release key stored in protected CI secrets and document backup/recovery.
10. **Operations:** exercise requests, assignment, reviews, permits, inspections, restoration, coordination, notifications and evidence integrity with controlled test accounts and records.

## 6. Decision

The latest source is improved and a new Alpha 0.3 APK is verified at the build/package level. The original integration branch remains untouched.

**Do not call this SAMANVAY 1.0 yet.** The current release still lacks physical-device acceptance, verified mobile OTP/recovery, safe profile editing, operational verified underground asset coverage, full authorization review, accessibility/performance evidence and production signing. Continue from this branch and close the acceptance gates in the baseline report before declaring 1.0.


## 7. GIS light-mode layer-sheet remediation

The GIS layer bottom sheet uses the theme's `panelNavy` surface, which is white in the legacy light palette. Its readiness headings, data integrity heading, switch titles and utility-screening text now use the active semantic foreground (`ink`) rather than fixed white. Deliberately dark map overlays retain white text. The first attempt introduced five invalid constant expressions; Android run #620 caught the issue during Dart analysis. Those five constant declarations were corrected in commit `5d45318`.

**Latest successful GIS-light-mode build:** [Android run #621](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/43381818460), commit `5d453184a21fe68717044856b269d0ed4295fc19`. All configured build, analyzer, APK package, signature, alignment and artifact-publishing steps passed.

- Artifact ID: `14017640919`
- Artifact ZIP SHA-256: `3ad74e3a2433e75914bcd290841f3bccfa3cd412e1c87cd8cda88225bd1c9bb4`
- ARM64 APK SHA-256: `80912abd77db82f82a1882073423faf3627960dc48095e23d7f3e678dcb26cdb`
- Logo Git blob SHA within the built APK: `17c2db21509cfb59109cd413e8cb0f24d3f66524`, matching the original asset exactly.

This remains an Alpha 0.3 package and does not replace physical-device light/dark visual acceptance.


## 8. Profile-editor build #622 — package verification

**Source commit:** `d17f235dea3552037b06e2bb7bef89e92fe0f07e`  
**Workflow:** [Android run #622](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/actions/runs/43383107121) — all configured steps completed successfully, including contract validation, Dart analysis, release APK compilation, package/signature/alignment checks and artifact publication.

**Artifact:** `SAMANVAY-Alpha-0.3-APK`  
**Artifact ID:** `14017059773`  
**Artifact ZIP SHA-256:** `c00fc77b048cba15d24a7bacdbebddf697f45259804b8af02ab07110eb6a4a99`

The downloaded artifact ZIP passed independent SHA-256 and ZIP CRC verification. All three ABI APKs passed independent ZIP CRC verification and contain the expected DEX and Flutter runtime libraries.

| ABI | APK size | SHA-256 |
|---|---:|---|
| ARM64 | 33,583,252 bytes | `ec101c510a1f79ddaaec1e07a288e74294d69792131eb1695acfafd163b8ea4d` |
| x86_64 | 35,435,001 bytes | `990eb1e617485b58832ac093f652a191573de844b4671fb2bae55e245ff842cd` |
| armeabi-v7a | 28,524,798 bytes | `3d1dffb356050076a7374b92a9c8c413c6ffc8b4b05164d5b563daff9f5c584a` |

The original logo asset inside all three APKs has Git blob SHA `17c2db21509cfb59109cd413e8cb0f24d3f66524`, matching the original source logo exactly.

**What this proves:** the profile-editor source revision compiles and its APK packages are structurally intact; the original logo is preserved.  
**What this does not prove:** actual installation, UI rendering, authenticated profile save, device compatibility, production signing or full application acceptance. These remain explicit QA gates.


## 9. Follow-up authentication and database-security inspection

### OTP delivery function

The Supabase project contains an ACTIVE `samanvay-dual-channel-otp` Edge Function (version 2). It validates the Supabase Auth Hook signature before reading the event, checks E.164 phone format and six-digit OTP format, and submits the same Supabase-issued OTP to configured Twilio SMS and WhatsApp providers. It does not log or return the OTP or recipient phone number. The function requires server-side secrets for the hook signature and Twilio provider credentials, including an approved WhatsApp Content Template; India SMS DLT identifiers are supported as optional paired settings.

**Not yet verified:** the Auth Hook is actually enabled and points to this function, all required secrets are present and valid, Twilio accepts both messages, or a real device receives and verifies the code. The mobile UI itself correctly states that provider delivery depends on project configuration. Therefore mobile OTP remains a release blocker, not a completed feature.

### SECURITY DEFINER review — static inspection

A fresh database query inspected every SECURITY DEFINER function in the exposed `public` schema that is executable by `authenticated`:

- 18 functions are executable by `authenticated`;
- none of those 18 is executable by `anon`;
- all 18 set an empty `search_path`;
- all 18 reference `auth.uid()` and role/identity-related logic;
- 16 contain explicit exception rejection paths; two are boolean/data helper functions whose authorization behavior is expressed by their query predicates.

Representative admin functions explicitly require `profiles.role = 'admin'`; department review/assignment functions check department role or assignment; the underground overview requires an authenticated profile with an allowed platform role and returns only generalised verified aggregates. This supports the conclusion that the advisor warning needs function-by-function grant/guard review rather than indiscriminate revocation.

**Remaining:** adversarial caller tests using separate Citizen, department, coordinator, admin and unauthenticated sessions have not been run. Static presence of `auth.uid()` and role checks is not proof that every possible caller/argument combination is safe. Keep the 18 warnings open until those negative tests and grant reviews are documented.

### Advisor snapshot after the profile migration

Observed 13 November 2026:
- Security: 18 authenticated SECURITY DEFINER notices; leaked-password protection disabled.
- Performance: 5 unindexed foreign keys, 81 unused-index notices, 14 multiple-permissive-policy notices and 1 duplicate-index notice.
- Health: no lints returned.

Unused-index notices are not sufficient reason to drop indexes without workload evidence. Multiple permissive policy findings need review for both correctness and query cost. No bulk index or policy changes were made.


## 10. OTP delivery evidence and security regression script

### Phone-registration status wording

The phone-signup UI now distinguishes an Auth API acceptance from confirmed delivery. It explicitly states that the six-digit code is pending and that the response does not prove it was delivered. This avoids telling a user to enter a code that may never have arrived.

### Live OTP hook evidence

The active `samanvay-dual-channel-otp` Edge Function is deployed (version 2), but the available 24-hour `function_edge_logs` window returned:
- invocations: `0`;
- successful responses: `0`;
- error responses: `0`.

The Auth logs in that same window show email/password login activity, but no evidence that the SMS hook was invoked. This does not establish whether the hook is unconfigured, unused, or awaiting a phone signup attempt. It does establish that delivery has not yet been proven. The project owner must verify the Supabase Send SMS Hook configuration, server-side hook secret, Twilio SMS sender/Messaging Service, WhatsApp approved Content Template and India DLT configuration, then perform a consented test-number flow. No OTP or provider secret was generated, exposed or sent during this audit.

### Repeatable catalog guard

Added `scripts/audit_security_definer.sql`. It is read-only and asserts:
- every authenticated-executable `public` SECURITY DEFINER RPC is not executable by `anon`;
- each inspected function has an empty `search_path`;
- each references `auth.uid()`;
- authenticated profile writes remain limited to `display_name`, never `role` or `department_id`, with no unrestricted table UPDATE grant.

The script is a static catalog/privilege guard. It does **not** prove that an authenticated malicious caller is rejected for every RPC argument or resource ID. Role-specific adversarial tests remain required.


## 11. Verified RPC authorization checks

A live negative-path SQL test was run against the current Supabase project using one existing profile per role and simulated JWT claims in a controlled transaction:
- Citizen: denied 6 protected RPC operations (admin directory, department creation, role update, assignment, overall status change and department review).
- Department Officer: denied 3 coordinator/admin operations (admin directory, assignment and overall status change).
- Coordinator: denied 3 administrator-only operations (admin directory, department creation and role update).
- Administrator: successfully read the account directory through the read-only positive path.

No test changed a role, department assignment, case status or department record. The repeatable script is committed at `scripts/test_role_rpc_authorization.sql`.

These tests exercise PostgreSQL function guards with simulated identity claims; they do not replace API requests using separately signed role JWTs or full device journeys.

## 12. GIS performance baseline and client cache

A sampled 24-hour Supabase Edge log window for `samanvay-public-boundaries` recorded 13/13 successful responses, zero HTTP errors, p50 execution time 1,765 ms, p95 3,246.6 ms, and maximum response payload 2,911,887 bytes. This is a limited observed sample, not a universal benchmark.

The Flutter map previously invoked this endpoint again when MapLibre recreated its style and the India ADM1/ADM2 sources had to be re-added. This increment adds a six-hour in-memory cache for validated public boundary payloads, keyed separately by ADM1 and ADM2. Repeated style reloads in the same app process can reuse the GeoJSON instead of downloading it again. Process restart or cache expiry still fetches from the Edge Function, which retains its own six-hour provider cache. Post-change request counts and map-render latency still need measurement.


## 13. Live profile RLS verification

A transaction-level test was run with `SET LOCAL ROLE authenticated` and a Citizen's JWT claim:
- `UPDATE public.profiles SET display_name = display_name WHERE id = auth.uid()` returned `own_display_name_update_allowed = true`.
- The transaction was rolled back; no profile value changed.
- A corresponding attempt to update `role` was rejected by PostgreSQL with SQLSTATE `42501` (permission denied for table `profiles`).

This verifies the active RLS/column-grant path for the display-name editor and confirms normal authenticated clients cannot update the protected role column.


### Profile row-visibility check

A separate transaction under `SET LOCAL ROLE authenticated` returned:
- own profile rows visible: 1;
- other users' profile rows visible: 0.

The transaction was rolled back after the check. Together with the own-display-name update test and the denied `role` update, this confirms the current self-row profile RLS path and least-privilege column grant at the database layer.
