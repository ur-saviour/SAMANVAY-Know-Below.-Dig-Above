import "jsr:@supabase/functions-js/edge-runtime.d.ts";

type Json = Record<string, unknown>;
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const SHA256 = /^[0-9a-f]{64}$/i;
function json(status: number, body: Json): Response {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
}
function keys() {
  const url = Deno.env.get("SUPABASE_URL");
  const publishable = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_PUBLISHABLE_KEY");
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !publishable || !service) throw new Error("FUNCTION_CONFIG_MISSING");
  return { url, publishable, service };
}
function text(value: unknown, min: number, max: number): string | null {
  if (typeof value !== "string") return null;
  const v = value.trim();
  return v.length >= min && v.length <= max ? v : null;
}
async function rpc(config: ReturnType<typeof keys>, name: string, body: Json): Promise<unknown> {
  const response = await fetch(config.url + "/rest/v1/rpc/" + name, {
    method: "POST",
    headers: { apikey: config.service, Authorization: "Bearer " + config.service, "Content-Type": "application/json" },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(20000),
  });
  if (!response.ok) throw new Error("RPC_FAILED");
  return await response.json();
}
Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json(405, { error: "METHOD_NOT_ALLOWED" });
  const token = (req.headers.get("Authorization") ?? "").match(/^Bearer\s+(.+)$/i)?.[1];
  if (!token) return json(401, { error: "AUTHENTICATION_REQUIRED" });

  let body: Json;
  try {
    const raw = await req.text();
    if (new TextEncoder().encode(raw).length > 12000) return json(413, { error: "REQUEST_TOO_LARGE" });
    body = JSON.parse(raw) as Json;
  } catch { return json(400, { error: "INVALID_JSON" }); }

  let config: ReturnType<typeof keys>;
  try { config = keys(); } catch { return json(503, { error: "FUNCTION_CONFIG_MISSING" }); }

  const auth = await fetch(config.url + "/auth/v1/user", {
    headers: { apikey: config.publishable, Authorization: "Bearer " + token },
    signal: AbortSignal.timeout(12000),
  });
  if (!auth.ok) return json(401, { error: "INVALID_SESSION" });
  const user = await auth.json() as { id?: string };
  if (!user.id || !UUID.test(user.id)) return json(401, { error: "INVALID_SESSION" });

  const profileUrl = new URL(config.url + "/rest/v1/profiles");
  profileUrl.searchParams.set("select", "role,department_id");
  profileUrl.searchParams.set("id", "eq." + user.id);
  const profileResponse = await fetch(profileUrl, {
    headers: { apikey: config.service, Authorization: "Bearer " + config.service },
    signal: AbortSignal.timeout(12000),
  });
  if (!profileResponse.ok) return json(503, { error: "PROFILE_LOOKUP_FAILED" });
  const profiles = await profileResponse.json() as Array<{ role: string; department_id: string | null }>;
  const profile = profiles[0];
  if (!profile || profile.role !== "department" || !profile.department_id) {
    return json(403, { error: "ASSIGNED_DEPARTMENT_ACCOUNT_REQUIRED" });
  }

  if (body.action === "list") {
    try {
      const items = await rpc(config, "list_department_asset_evidence_queue_server", { p_actor_id: user.id });
      return json(200, { ok: true, items });
    } catch { return json(503, { error: "EVIDENCE_QUEUE_UNAVAILABLE" }); }
  }
  if (body.action !== "submit") return json(400, { error: "UNSUPPORTED_ACTION" });

  const assetId = typeof body.asset_id === "string" ? body.asset_id : "";
  const method = text(body.survey_method, 3, 40);
  const surveyDate = text(body.survey_date, 10, 10);
  const organisation = text(body.surveyor_organisation, 3, 200);
  const reference = text(body.evidence_reference_code, 3, 120);
  const checksum = typeof body.evidence_sha256 === "string" ? body.evidence_sha256.trim().toLowerCase() : "";
  const storagePath = typeof body.evidence_storage_path === "string" ? body.evidence_storage_path.trim() : "";
  const notes = body.notes === null || body.notes === undefined ? null : text(body.notes, 0, 1000);
  const pathParts = storagePath.split("/");
  const validPath = UUID.test(assetId) && pathParts.length === 3 &&
    pathParts[0] === assetId && pathParts[1] === user.id &&
    /^[A-Za-z0-9._-]{1,180}\.(pdf|jpg|jpeg|png|webp)$/i.test(pathParts[2] ?? "");
  if (!UUID.test(assetId) || !method || !surveyDate || !/^\d{4}-\d{2}-\d{2}$/.test(surveyDate) ||
      !organisation || !reference || !SHA256.test(checksum) || !validPath ||
      (body.notes !== null && body.notes !== undefined && notes === null)) {
    return json(400, { error: "EVIDENCE_METADATA_OR_PRIVATE_FILE_PATH_INVALID" });
  }

  try {
    const evidenceId = await rpc(config, "register_asset_survey_evidence_with_file_server", {
      p_actor_id: user.id,
      p_asset_id: assetId,
      p_survey_method: method,
      p_survey_date: surveyDate,
      p_surveyor_organisation: organisation,
      p_evidence_reference_code: reference,
      p_evidence_sha256: checksum,
      p_storage_path: storagePath,
      p_notes: notes,
    });
    return json(200, { ok: true, evidence_id: evidenceId });
  } catch {
    return json(409, { error: "EVIDENCE_NOT_RECORDED", detail: "Confirm the file was uploaded to the private evidence bucket and the asset belongs to your assigned department." });
  }
});