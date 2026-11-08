import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
function reply(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
}
Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply(405, { error: "METHOD_NOT_ALLOWED" });
  const token = (req.headers.get("Authorization") ?? "").match(/^Bearer\s+(.+)$/i)?.[1];
  if (!token) return reply(401, { error: "AUTHENTICATION_REQUIRED" });
  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return reply(400, { error: "INVALID_JSON" }); }
  const assetId = String(body.asset_id ?? "");
  const decision = String(body.decision ?? "");
  const rationale = typeof body.rationale === "string" ? body.rationale.trim() : "";
  if (!uuid.test(assetId) || !["approve", "reject"].includes(decision) || rationale.length < 10 || rationale.length > 2000) {
    return reply(400, { error: "ASSET_DECISION_OR_RATIONALE_INVALID" });
  }
  const url = Deno.env.get("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anon || !service) return reply(503, { error: "FUNCTION_CONFIG_MISSING" });

  const userResponse = await fetch(url + "/auth/v1/user", {
    headers: { apikey: anon, Authorization: "Bearer " + token },
    signal: AbortSignal.timeout(12000),
  });
  if (!userResponse.ok) return reply(401, { error: "INVALID_SESSION" });
  const user = await userResponse.json() as { id?: string };
  if (!user.id || !uuid.test(user.id)) return reply(401, { error: "INVALID_SESSION" });

  const profileUrl = new URL(url + "/rest/v1/profiles");
  profileUrl.searchParams.set("select", "role");
  profileUrl.searchParams.set("id", "eq." + user.id);
  const profileResponse = await fetch(profileUrl, {
    headers: { apikey: service, Authorization: "Bearer " + service },
    signal: AbortSignal.timeout(12000),
  });
  if (!profileResponse.ok) return reply(503, { error: "PROFILE_LOOKUP_FAILED" });
  const profiles = await profileResponse.json() as Array<{ role: string }>;
  if (!["admin", "coordinator"].includes(profiles[0]?.role ?? "")) return reply(403, { error: "REVIEWER_ROLE_REQUIRED" });

  const rpc = await fetch(url + "/rest/v1/rpc/review_underground_asset_submission", {
    method: "POST",
    headers: { apikey: service, Authorization: "Bearer " + service, "Content-Type": "application/json" },
    body: JSON.stringify({ p_actor_id: user.id, p_asset_id: assetId, p_decision: decision, p_rationale: rationale }),
    signal: AbortSignal.timeout(20000),
  });
  if (!rpc.ok) return reply(409, { error: "REVIEW_NOT_COMPLETED", detail: "The submission may lack required evidence or may no longer be reviewable." });
  const result = await rpc.json();
  return reply(200, result as Record<string, unknown>);
});
