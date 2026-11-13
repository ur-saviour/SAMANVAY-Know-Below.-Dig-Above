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
