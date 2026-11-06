import { createClient } from "npm:@supabase/supabase-js@2.58.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};
const RESOURCE_ID = "6857c02f-c77e-4576-b349-3e45aacc1c21";
const SOURCE_URL = "https://nwdp.nwic.gov.in/en/dataset/ground-water-level-telemetry-daily-tamil-nadu-sw-gw/resource/6857c02f-c77e-4576-b349-3e45aacc1c21";
const DATA_API = "https://nwdp.nwic.gov.in/api/3/action/datastore_search";
const DISTRICT = "Coimbatore";
const PAGE_SIZE = 1000;
const UPSERT_BATCH = 500;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: corsHeaders });
}
function nullableNumber(value: unknown): number | null {
  if (value === null || value === undefined) return null;
  const valueText = String(value).trim();
  if (!valueText || valueText === "-" || valueText.toLowerCase() === "null") return null;
  const parsed = Number(valueText);
  return Number.isFinite(parsed) ? parsed : null;
}
function localTimestamp(value: unknown): string | null {
  const match = String(value ?? "").trim().match(/^(\d{2})-(\d{2})-(\d{4})\s+(\d{2}):(\d{2})$/);
  if (!match) return null;
  const day = match[1], month = match[2], year = match[3], hour = match[4], minute = match[5];
  return year + "-" + month + "-" + day + "T" + hour + ":" + minute + ":00";
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "POST required." }, 405);

  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace(/^Bearer\s+/i, "").trim();
  if (!token) return json({ error: "A signed-in SAMANVAY session is required." }, 401);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceKey) {
    return json({ error: "Required Supabase function environment is unavailable." }, 500);
  }

  const authClient = createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const authResult = await authClient.auth.getUser(token);
  if (authResult.error || !authResult.data.user) return json({ error: "Invalid or expired session." }, 401);

  const userId = authResult.data.user.id;
  const profileResult = await admin.from("profiles").select("role").eq("id", userId).maybeSingle();
  if (profileResult.error || !profileResult.data ||
      !["requester", "department", "coordinator", "admin"].includes(profileResult.data.role)) {
    return json({ error: "A valid SAMANVAY profile is required." }, 403);
  }

  const cutoff = new Date(Date.now() - 15 * 60 * 1000).toISOString();
  const staleResult = await admin.from("groundwater_data_import_runs").update({
    status: "failed",
    completed_at: new Date().toISOString(),
    error_summary: "Import lease expired before completion; safe to retry.",
  }).eq("status", "running").lt("started_at", cutoff);
  if (staleResult.error) return json({ error: "Could not clear an expired import lease." }, 500);

  const activeResult = await admin.from("groundwater_data_import_runs")
    .select("id").eq("status", "running").gte("started_at", cutoff).limit(1);
  if (activeResult.error) return json({ error: "Could not check import status." }, 500);
  if (activeResult.data && activeResult.data.length > 0) {
    return json({ error: "A groundwater import is already running.", run_id: activeResult.data[0].id }, 409);
  }

  const freshnessCutoff = new Date(Date.now() - 6 * 60 * 60 * 1000).toISOString();
  const recentResult = await admin.from("groundwater_data_import_runs")
    .select("id,completed_at,records_imported").eq("status", "completed")
    .gte("completed_at", freshnessCutoff).order("completed_at", { ascending: false }).limit(1);
  if (recentResult.error) return json({ error: "Could not check the last successful import." }, 500);
  if (recentResult.data && recentResult.data.length > 0) {
    return json({
      status: "already_fresh",
      district: DISTRICT,
      last_completed_at: recentResult.data[0].completed_at,
      records_imported_last_run: recentResult.data[0].records_imported,
      message: "A successful import completed within the last six hours.",
    });
  }

  const runResult = await admin.from("groundwater_data_import_runs").insert({
    source_resource_id: RESOURCE_ID,
    district_scope: DISTRICT,
    status: "running",
    requested_by: userId,
  }).select("id").single();
  if (runResult.error || !runResult.data) {
    if (runResult.error?.code === "23505") return json({ error: "Another groundwater import started at the same time." }, 409);
    return json({ error: "Could not create the import audit record." }, 500);
  }

  const runId = runResult.data.id;
  let imported = 0;
  let total = 0;
  try {
    let offset = 0;
    while (true) {
      const url = new URL(DATA_API);
      url.searchParams.set("resource_id", RESOURCE_ID);
      url.searchParams.set("filters", JSON.stringify({ District: DISTRICT }));
      url.searchParams.set("limit", String(PAGE_SIZE));
      url.searchParams.set("offset", String(offset));

      const response = await fetch(url.toString(), {
        headers: { "Accept": "application/json", "User-Agent": "SAMANVAY-Government-Data-Importer/1.0" },
        signal: AbortSignal.timeout(25000),
      });
      if (!response.ok) throw new Error("NWDP returned HTTP " + response.status + ".");
      const payload = await response.json();
      if (payload?.success !== true || !payload?.result || !Array.isArray(payload.result.records)) {
        throw new Error("NWDP returned an unexpected datastore response.");
      }

      const sourceRows = payload.result.records as Record<string, unknown>[];
      total = Number(payload.result.total ?? total);
      if (sourceRows.length === 0) break;

      const mapped = sourceRows.map((row) => {
        const timestamp = localTimestamp(row["Data Acquisition Time"]);
        const sourceId = Number(row["_id"]);
        const station = String(row["Station"] ?? "").trim();
        if (!Number.isSafeInteger(sourceId) || !timestamp || !station) return null;
        const rawLevel = row["Groundwater Level Telemetry 6 Hourly (meter)"];
        return {
          source_resource_id: RESOURCE_ID,
          source_record_id: sourceId,
          station_name: station,
          agency: String(row["Agency"] ?? "Tamil Nadu SW GW"),
          state_lgd_code: String(row["State LGD Code"] ?? ""),
          state_name: String(row["State"] ?? "Tamil Nadu"),
          district_lgd_code: String(row["District LGD Code"] ?? ""),
          district_name: String(row["District"] ?? DISTRICT),
          tehsil: String(row["Tehsil"] ?? ""),
          block_name: String(row["Block"] ?? ""),
          village_name: String(row["Village"] ?? ""),
          latitude: nullableNumber(row["Latitude"]),
          longitude: nullableNumber(row["Longitude"]),
          rl_msl_m: nullableNumber(row["RL_MSL"]),
          observed_at_local: timestamp,
          reported_level_m: nullableNumber(rawLevel),
          reported_level_text: rawLevel === null || rawLevel === undefined ? null : String(rawLevel),
          source_dataset_url: SOURCE_URL,
        };
      }).filter((row): row is NonNullable<typeof row> => row !== null);

      for (let i = 0; i < mapped.length; i += UPSERT_BATCH) {
        const batch = mapped.slice(i, i + UPSERT_BATCH);
        const upsertResult = await admin.from("groundwater_station_observations")
          .upsert(batch, { onConflict: "source_resource_id,source_record_id" });
        if (upsertResult.error) throw new Error("Database upsert failed: " + upsertResult.error.message);
        imported += batch.length;
      }

      offset += sourceRows.length;
      if (offset >= total || sourceRows.length < PAGE_SIZE) break;
    }

    const completeResult = await admin.from("groundwater_data_import_runs").update({
      status: "completed",
      records_imported: imported,
      source_records_total: total,
      completed_at: new Date().toISOString(),
    }).eq("id", runId);
    if (completeResult.error) throw new Error("Imported rows but could not close the audit record.");

    return json({
      status: "completed",
      district: DISTRICT,
      source_resource_id: RESOURCE_ID,
      source_records_total: total,
      records_imported: imported,
      run_id: runId,
      source_url: SOURCE_URL,
      note: "Published source values and local observation timestamps are preserved; no legal or safety classification is inferred.",
    });
  } catch (error) {
    const summary = String(error instanceof Error ? error.message : error).slice(0, 500);
    await admin.from("groundwater_data_import_runs").update({
      status: "failed",
      records_imported: imported,
      source_records_total: total,
      completed_at: new Date().toISOString(),
      error_summary: summary,
    }).eq("id", runId);
    return json({ status: "failed", district: DISTRICT, records_imported_before_failure: imported, error: summary }, 502);
  }
});
