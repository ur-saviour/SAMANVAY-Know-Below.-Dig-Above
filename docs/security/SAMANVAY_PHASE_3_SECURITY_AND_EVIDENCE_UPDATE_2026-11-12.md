# SAMANVAY — Phase 3 Security and Phase 4 Evidence Update

**Execution date:** 12 November 2026  
**Working branch:** `feature/alpha-03-integrated-platform`  
**Supabase project:** `zhtotivedvkmclerdnlf`

## 1. Phase 3 — Storage helper hardening

Migration `20261112170055_move_storage_evidence_helpers_to_private_schema` was applied to the live Supabase project and committed to the working branch at:

- Commit: `292bb590b8e4f2322c9ca47f8f67366c25166362`
- Migration: `supabase/migrations/20261112170055_move_storage_evidence_helpers_to_private_schema.sql`

The following storage-policy helpers were moved from the exposed `public` schema into the existing `private` schema:

- `can_access_utility_asset_evidence_path(text, uuid)`
- `can_delete_utility_asset_evidence_path(text, uuid, text)`

The migration re-bound all three owner-department survey-evidence Storage policies to the private helpers, retained the caller identity check against `auth.uid()`, retained the assigned-department and import-provenance checks, and removed the public RPC functions. Only the authenticated database role receives the minimum schema/function privileges required by Storage RLS evaluation; `anon` is denied.

### Live verification

| Check | Result |
|---|---|
| Authenticated can execute private access helper | Pass |
| Authenticated can execute private delete helper | Pass |
| Anonymous can execute either private helper | Denied |
| Public access-helper RPC remains | No |
| Public delete-helper RPC remains | No |
| Three Storage policies reference the private helpers | Pass |
| Migration recorded in Supabase migration history | Pass |

The Supabase security advisor's authenticated SECURITY DEFINER finding count fell from 18 to 16 after the migration. The remaining 16 are not blanket-revoked because several support core request, inspection, role administration, GIS, and coordination workflows. A structural query confirmed that these remaining functions reference `auth.uid()`, pin an empty `search_path`, and deny anonymous execution. Their role/ownership rules still require ongoing adversarial regression testing.

### Remaining Phase 3 issue

Supabase Auth leaked-password protection remains disabled. This is a project Auth setting and was not changed by the database migration. A project owner must enable it in the Supabase Auth password-security settings and verify the setting afterwards.

The database security advisor also continues to identify the 16 intentional authenticated SECURITY DEFINER entry points. These findings are monitored risks, not a clean security certification.

## 2. Existing evidence-storage baseline

The live database currently has two private Storage buckets, each limited to 20 MiB and restricted to PDF/JPEG/PNG/WEBP:

- `samanvay-case-evidence`
- `samanvay-asset-survey-evidence`

At the time of this audit:

| Evidence metric | Live value |
|---|---:|
| Case attachment metadata records | 1 |
| Case evidence Storage objects | 1 |
| Owner-department utility evidence objects | 0 |
| Case attachment records with SHA-256 metadata | 0 |
| Field inspection records | 0 |

Case files use request-linked metadata and authenticated case-participant access. Owner-department utility evidence uses a separate department-scoped Storage policy and private queue. The two evidence classes must not be treated as interchangeable.

## 3. Phase 4 — Case evidence upload improvements

Commit `ada2d3da8ff48381e83d687f68a4ed4598fb49a6` updates `app/main.dart`:

1. The upload UI now asks the user to classify the file as a site photograph, survey evidence, permit/approval, technical drawing, inspection report, or other case document.
2. The client verifies that the selected byte stream is non-empty and exactly matches the reported file size before upload.
3. The client computes a SHA-256 fingerprint from the bytes it uploads and records it in `case_attachments.sha256`.
4. The private case-evidence list displays the document category and the local SHA-256 value.
5. Older evidence without a checksum remains viewable and is labelled as having no recorded SHA-256.

**Integrity limit:** the current case-upload flow computes the checksum on the client. This fingerprints the bytes supplied by that client but is not independent server-side checksum verification and does not prove document authorship, source authority or legal validity. It must not be described as a verified digital signature.

The owner-department utility evidence flow separately re-fetches the uploaded object on the server, recomputes its checksum, and compares it before registering the evidence metadata.

## 4. Phase 4 — Remaining implementation work

The evidence/document-management workstream is not closed. Remaining work includes:

- Server-side checksum verification for ordinary case attachments.
- Document source authority, source reference, validity dates and reviewer decision metadata.
- Append-only audit events for upload, replacement, review, revocation and authorised access.
- A staff evidence-review interface with case/department-scoped permissions.
- Explicit replacement and revocation workflows that preserve prior evidence history.
- Adversarial tests for citizen, assigned department, unassigned department, coordinator and administrator access.
- Physical-device and browser testing of file selection, upload, signed URL access and expired links.

AI-assisted extraction, when enabled, must remain draft assistance with page/source references and a human review gate. Extracted values must not become official records automatically.

## 5. Release validation

The preceding GIS/application commit `fea9c99` passed both Android APK build run 453 and browser portal build run 321.

The latest Phase 4 UI commit `ada2d3d` triggered Android APK run 454 and browser portal run 322. Their final conclusions must be checked in GitHub Actions before distributing a new APK. A CI build does not replace manual testing on a physical Android device.

## 6. Current decision

- **Phase 2 build prerequisite:** cleared by the successful Android and browser runs on `fea9c99`.
- **Phase 3 storage-helper hardening:** applied and live-verified.
- **Phase 3 overall security closure:** incomplete; Auth leaked-password protection and adversarial authorization coverage remain open.
- **Phase 4 evidence UI improvement:** committed; automated build validation pending at the time of this report.
- **Phase 4 overall closure:** incomplete; server verification, provenance, review workflow and access audit trail remain open.

No synthetic underground asset geometry, survey evidence or authority approval has been created to make the project appear complete.
