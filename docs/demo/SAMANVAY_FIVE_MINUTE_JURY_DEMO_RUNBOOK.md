# SAMANVAY — Five-Minute Jury Demonstration Runbook

**Build:** Alpha 0.3  
**Branch:** `feature/alpha-03-integrated-platform`  
**Audience:** Innovation / civic technology jury  
**Duration:** 5 minutes  
**Mode:** Prototype demonstration; sample workflows are session-local and clearly labelled.

## Before starting (30 seconds, off-script)

1. Install the latest ARM64 APK on the demonstration Android device, or open the browser portal.
2. Confirm the demo preview opens from My Profile → Switch profiles.
3. Keep the network available for the live India basemap. The subsurface sandbox is local and does not need a real utility dataset.
4. Do not sign into a real account and describe a demo preview as a privileged live account. The switcher opens a local sample workspace; it does not change the signed-in database role.
5. Do not describe a blank underground layer as a clear-to-dig result.

## Five-minute sequence

### 0:00–0:35 — The citizen problem

- Open the Citizen demo profile.
- Explain that citizens can submit an excavation / road obstruction / utility coordination request and follow its status.
- Open the sample Avinashi Road water-pipeline request.
- Point out the request number, location, responsible department and shared case history.

Suggested line: “A citizen should not have to discover which of several departments owns a road or utility problem. SAMANVAY gives the request one traceable case record.”

### 0:35–1:20 — Department officer workflow

- Use Switch profiles → Department Officer.
- Open Case queue.
- Open the water pipeline replacement sample.
- Show the department review, clarification, inspection and evidence actions.
- Explain that real evidence files and field captures are protected by account-level permissions; the preview actions shown here are session-local.

Suggested line: “The department sees the cases routed to it, adds technical review and records evidence without exposing another utility owner’s exact routes.”

### 1:20–2:00 — Coordinator and joint work

- Switch to Coordinator.
- Open Coordination.
- Show the multi-department request and joint-work proposal.
- Show the shared work window and response / decision trail.
- Explain that each owner retains its own clearance authority.

Suggested line: “Before the road is reopened, the platform can surface related work packages so departments can consider a common access window rather than scheduling unrelated cuts.”

### 2:00–2:45 — Administrator and national readiness

- Switch to Administrator.
- Open Admin oversight and India GIS / coverage.
- Show all 36 States / UTs, 11 infrastructure domains, the coverage matrix and source-vintage labels.
- Show the ULB-to-district reconciliation queue only if the jury asks about governance of reference data.
- Explain that 5,050 ULB mappings are deliberately unmapped until supported by source evidence.

Suggested line: “Nationwide navigation is present, but reference records remain marked unverified until reconciled with the authorised source. A large directory is not the same as certified data.”

### 2:45–3:35 — GIS and subsurface model

- Open GIS.
- Toggle vector / satellite, 2D / 3D and the public reference layers.
- Open the India regional jump and North India entry.
- Show the subsurface visualisation sandbox; toggle water, sewer, stormwater, electricity, telecom, gas and borewell layers.
- Explain that this teaching visual is synthetic and not georeferenced.
- State that exact underground geometry is empty in the live registry and owner-controlled.

Suggested line: “The map separates public reference information, generalised coverage and verified owner-controlled geometry. An empty or unverified layer is never excavation clearance.”

### 3:35–4:20 — Road-cut and restoration lifecycle

- Open Roadworks.
- Advance one sample permit through Work started → Work completed → Restoration verified.
- Show the permit activity trail and the restoration state.
- State that the sample permit is synthetic and does not grant legal excavation permission.

Suggested line: “The same case can be followed beyond approval, through work commencement, completion and restoration review.”

### 4:20–4:50 — Pilot impact simulation

- Open Pilot & impact.
- Run the illustrative corridor scenario.
- Show three assumed work packages, three assumed independent access windows and one modelled shared window.
- State that the difference is a planning illustration, not an observed saving or measured result.

Suggested line: “This is how a pilot could measure coordination value. Actual outcomes will be reported only after an authorised baseline and timestamped work records exist.”

### 4:50–5:00 — Close

Suggested line: “SAMANVAY brings citizens, departments and infrastructure references into one accountable workflow. The prototype demonstrates the coordination process; authority approvals, verified utility records and a measured field pilot are the next validation gates.”

## Claims to avoid

- Do not claim that underground utility routes are complete or certified.
- Do not claim that a location is safe to excavate because the map is blank.
- Do not claim the 20,238 imported administrative records are authority-verified.
- Do not claim the groundwater table contains its original complete history. Live data currently contains 446,068 calendar-2025 rows; the verified 1,911,126-row encrypted pre-change archive has not been restored.
- Do not describe demo role switching as a live change of the signed-in account role.
- Do not present the Pilot & impact calculation as actual savings, avoided cuts or government performance.
- Do not describe the demo permit as a statutory road-cut permit.

## Current validation boundary

- Android Alpha 0.3 build: passed release build, signing / alignment checks and artifact publication in GitHub Actions.
- Browser portal build: passed Dart analysis, browser compilation and GIS asset smoke tests.
- ULB-to-district queue: 5,050 rows remain unmapped. Admin/coordinator read and department denial tests passed; mapping validation tests were rolled back.
- Groundwater historical recovery: not executed. The new archive-verification workflow is manual-only and restores only into disposable local PostgreSQL.
- Device acceptance: still requires a real device check for sign-in, camera, GPS, notifications, file upload, map tile load and offline behavior.
