# SAMANVAY Groundwater Data Recovery Incident

**Incident date:** 9 November 2026  
**Detection / confirmation:** 13 November 2026  
**Scope:** `public.groundwater_station_observations` in Supabase project `zhtotivedvkmclerdnlf`  
**Repository branch:** `feature/alpha-03-integrated-platform`

## Executive finding

A GitHub Actions recovery workflow committed a production `TRUNCATE` and reloaded only calendar-year 2025 records. The production table changed from 1,911,126 rows to 446,068 rows. The current table contains only 2025 records.

This was caused by the v4 legacy workflow, not by the current security hardening migrations.

## Timeline (UTC)

| Time | Evidence |
|---|---|
| 19:47:46, 9 Nov | Full encrypted PostgreSQL backup workflow run 42686760504 started and completed successfully |
| 19:53:50, 9 Nov | Full database archive release `samanvay-db-archive-42686760504` published; download, checksum, decrypt and PostgreSQL catalogue verification passed |
| 20:17:17, 9 Nov | Groundwater-specific encrypted archive release `samanvay-groundwater-raw-archive-42691241449` published |
| 21:34–21:37, 9 Nov | Four legacy recovery variants and retries were automatically triggered by pushes |
| 21:37:53–21:39:03, 9 Nov | v4 run 42704213811 executed and committed the production truncate and 2025-only copy |
| 13 Nov | GitHub Actions logs and live SQL counts were correlated; incident confirmed |

## Workflow run analysis

| Run ID | Workflow | Result |
|---:|---|---|
| 42703812857 | Base recovery workflow | Failed in local archive extraction at `COPY 0`; no live truncate |
| 42703918033 | Base recovery retry | Failed SQL parsing before the live truncate step |
| 42703969678 | v2 recovery workflow | Failed SQL parsing before the live truncate step |
| 42704164596 | v3 recovery workflow | Failed on an invalid psql meta-command before the live truncate step |
| 42704213811 | v4 recovery workflow | **Production truncate and 2025-only reload succeeded; final verification failed later** |

Run 42704213811 records:
- The precondition check saw 1,911,126 live rows and 446,068 rows in 2025.
- The local archive was decrypted and restored in disposable PostgreSQL; 446,068 2025 records were exported and validated.
- Production command output included `TRUNCATE TABLE`, `COMMIT`, `COPY 446068`, the subsequent validation `DO` and a second `COMMIT`.
- It reported 446,068 retained rows and a 324 MB database.
- The next fresh-connection verification failed because of malformed timestamp quoting. That final-step failure did not roll back the earlier production commits.

## Current live database verification

- Total rows: 446,068.
- Rows outside 2025: 0.
- Date range: 2025-01-01 00:00 through 2025-12-31 18:00.
- Rows with both latitude and longitude: 445,553.
- Rows without a complete coordinate pair: 515.
- Current unique constraints: primary key `id`; unique `(source_resource_id, source_record_id)`.

## Recovery material

The pre-change encrypted archive exists:
- Full database backup release: [samanvay-db-archive-42686760504](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/releases/tag/samanvay-db-archive-42686760504).
- Groundwater table archive release: [samanvay-groundwater-raw-archive-42691241449](https://github.com/ur-saviour/SAMANVAY-Know-Below.-Dig-Above/releases/tag/samanvay-groundwater-raw-archive-42691241449).

The v4 workflow successfully decrypted the groundwater archive before the production write and checked that its restored table had the expected 1,911,126 rows. The encryption passphrase remains in the GitHub Actions secret store.

## Containment completed

- The four `recover-supabase-auth-readonly*` workflows have been deleted from the active branch.
- Their replacement `verify-groundwater-archive.yml` is manual-only and has no Supabase production connection credentials or write path; it restores only into disposable local PostgreSQL.
- Database import, archive, backup, restore-drill and WAL maintenance workflows are now manual-only.
- The production data was not changed during the 13 November audit.

## Safe restoration plan

1. Decrypt the archived table in an isolated PostgreSQL instance.
2. Confirm 1,911,126 source rows and the expected date and coordinate distributions.
3. Compare existing production 2025 rows against the archive using primary key and source natural key. Require exact value equivalence; do not overwrite mismatching live rows.
4. Produce a deterministic delta containing only missing historical records, with duplicate and foreign-key checks.
5. Review row counts, keys, hashes and expected resulting total.
6. Only after a separate production approval, insert the missing rows additively in a bounded transaction and verify all counts. Never execute another truncate.

**Status:** incident confirmed; automatic execution contained; pre-change encrypted recovery source verified by the original workflow; additive restoration not yet performed.
