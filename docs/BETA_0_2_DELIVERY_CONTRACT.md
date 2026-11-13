# SAMANVAY Beta 0.2 — Delivery Contract

**Status:** In progress  
**Baseline:** `main` at the time the branch was created  
**Working branch:** `beta-0.2-hardening`  
**Release rule:** Beta 0.2 is complete only when every P0 acceptance check below has implementation evidence and a successful Android build. A code commit or a green build alone is not feature acceptance.

## Non-negotiable product constraints

- Preserve the existing SAMANVAY logo asset and wordmark. Do not redraw, replace, recolor, or approximate the supplied identity.
- Implement the agreed opening animation using the existing brand assets; do not substitute a generic splash screen.
- Use **Citizen** consistently. Do not display the obsolete role label "Requester".
- Keep the authentication entry simple and mobile-first. Provide visible password recovery.
- Support citizen, departmental officer, coordinator, and administrator experiences with server-enforced authorization.
- GIS is a core public-facing feature, not an officials-only placeholder.
- Demonstration geometry must be explicitly labelled **Demonstration data — not a verified utility survey**. Never present fabricated utility alignments, depths, clearances, or conflict alerts as real.
- Preserve existing database records and migrations. No destructive schema reset.

## P0 acceptance matrix

| ID | Area | Acceptance evidence |
|---|---|---|
| A01 | Brand and opening | Existing approved logo asset is used unchanged; opening animation plays once, then routes correctly |
| A02 | Citizen registration | Mobile number capture, country code, OTP request, OTP verification, profile completion |
| A03 | Account recovery | Password reset flow is reachable from login and completes through the configured Supabase recovery mechanism |
| A04 | Email authentication | Existing email sign-in remains functional; invalid credentials and unconfirmed accounts show actionable errors |
| A05 | Role provisioning | Citizen self-registration cannot self-assign privileged roles; officer/coordinator/admin accounts are provisioned through trusted admin workflow |
| A06 | Authorization | Database RLS and server-side checks enforce role and department boundaries; hiding UI controls is not authorization |
| A07 | Role workspaces | Citizen, officer, coordinator, and administrator see distinct permitted navigation and actions |
| A08 | Citizen requests | Submit, list, view status, and attach evidence where schema/storage policy permits |
| A09 | Officer workflow | Assigned department can review and update only permitted requests; every transition is audited |
| A10 | Coordinator workflow | Cross-department coordination, status visibility, and escalation are available within granted scope |
| A11 | Administrator workflow | User/department management and audit visibility are restricted to administrators |
| A12 | GIS overview | Map opens for all roles; India → state → district → city/ward navigation and location search are available |
| A13 | GIS layers | Road/administrative context and utility categories have layer toggles, legend, and visible layer state |
| A14 | Underground view | Road cutaway shows separate utility corridors by category, depth bands, labels, and a 2D/3D presentation mode |
| A15 | Data integrity | Every demo feature is labelled; empty verified-asset state is explicit; no invented live/verified status |
| A16 | Resilience | Loading, empty, permission-denied, offline, and retry states are usable |
| A17 | Accessibility | Readable light/dark themes, contrast, touch targets, and text scaling |
| A18 | Android release | Clean dependency resolution, successful debug/release build, install and smoke test on Android |

## Implementation sequence

### Track 1 — Restore and stabilize baseline
1. Confirm the default branch, Flutter project root, dependency manifest, assets, and current CI workflow.
2. Keep changes isolated on `beta-0.2-hardening`; do not push directly to the default branch.
3. Run formatter, analyzer, tests, and APK build before feature changes to establish baseline failures.

### Track 2 — Identity and authentication
1. Inspect current logo and animation assets before touching splash/login code.
2. Add mobile OTP using Supabase Phone Auth and the configured SMS provider. OTP cannot be made production-functional by client UI alone; provider credentials and templates must be configured in Supabase.
3. Keep email sign-in if already enabled.
4. Add password recovery and explicit verification/error states.
5. Privileged role assignment must be performed by trusted server/admin code, never by an editable client-side role dropdown.

### Track 3 — Role-based operations
1. Resolve role and department from the trusted profile record.
2. Apply RLS policies to every request, evidence, assignment, and audit table.
3. Build separate citizen/officer/coordinator/admin workspaces using shared components.
4. Add audit events for sensitive workflow transitions.

### Track 4 — GIS and subsurface visualization
1. Replace the placeholder map with a real interactive map surface using a supported tile source and explicit attribution.
2. Add India/state/district/city/ward navigation and layer controls.
3. Add an underground cutaway panel with distinct water, sewer, drainage, electricity, telecom, and gas corridors.
4. Demo geometry may be used to prove visualization and interactions, but it must be visibly labelled and isolated from verified asset records.
5. Show depth/clearance as unavailable unless a source record contains surveyed values and vertical datum metadata.
6. Keep public map access read-only for sensitive infrastructure layers; expose only policy-approved detail.

### Track 5 — Verification and release
1. Run static analysis and automated tests.
2. Test auth flows, role isolation, RLS, request lifecycle, GIS layer controls, and empty/error states.
3. Build APK from a clean checkout.
4. Record exact build artifact, commit SHA, test results, and known limitations.
5. Open a pull request; do not merge until acceptance evidence is reviewed.

## Security and data rules

- Never commit Supabase service-role keys, SMS provider secrets, signing keys, or private tokens.
- Client apps use only the publishable/anon key with RLS enabled.
- Never grant privileged roles from user-editable metadata.
- Treat all uploaded evidence as untrusted; enforce size/type limits and storage access policies.
- Do not expose sensitive utility coordinates to unauthenticated users.
- Do not create real-world excavation safety claims from simulated geometry.

## Release reporting template

For each acceptance ID report one of: **PASS**, **FAIL**, **BLOCKED**, or **NOT TESTED**, with commit/test evidence. Overall completion is not 100% while any P0 item is FAIL, BLOCKED, or NOT TESTED.
