# SAMANVAY Phase 2 — Administrative hierarchy browser

**Date:** 12 November 2026  
**Branch:** `feature/phase-2-admin-hierarchy-browser`

## Implemented

Added a citizen-accessible State/UT → district browser. Selecting a district loads two separately identified child lists: sub-districts and blocks. The browser paginates at 500 rows, filters to active records with LGD codes, and displays each code, source system, source date and verification status. A district name/code search is included.

The screen states that imported data comes from a 21 October 2026 community mirror and that all rows remain unverified. It does not treat the mirror as an official live LGD connection or a statutory boundary source.

## Relationship checks against the live database

- 784 active LGD-coded districts; all have State/UT parent association through `state_ut_id`.
- 7,092 active LGD-coded sub-districts; all have a district `parent_unit_id`.
- 7,312 active LGD-coded blocks; all have a district `parent_unit_id`.
- No duplicate LGD codes were found within these active, code-bearing unit types in the audited snapshot.
- No sub-district or block parent links crossed State/UT boundaries.
- The source import does not establish a block-under-sub-district relationship. The UI therefore presents sub-districts and blocks as separate lists linked directly to their district.
- No ULB, gram-panchayat or ward records are present in the current import; the UI marks these categories pending rather than fabricating empty names or geometry.
- All listed records remain `imported_unverified`; authority-verified count is zero.

## Scope and guardrails

This is an administrative directory browser, not a boundary viewer. It publishes no utility routes, depths, exact underground asset geometry, borewell permissions or excavation clearance. District names and codes remain reference/navigation data until reconciled against an authority-generated export.

## Validation status

The new UI change must pass the Android and Web CI analysis/build/smoke tests triggered by the pull request before it is merged. No physical-device QA is claimed.
