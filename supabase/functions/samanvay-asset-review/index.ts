import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: corsHeaders,
  });
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json(405, { error: "METHOD_NOT_ALLOWED" });

  const contentLength = Number(req.headers.get("Content-Length") ?? "0");
  if (Number.isFinite(contentLength) && contentLength > 16_384) {
    return json(413, { error: "REQUEST_TOO_LARGE" });
  }

  // Parse a standard Authorization: Bearer <JWT> header.
  const authorization = (req.headers.get("Authorization") ?? "").trim();
  const bearer = /^Bearer\s+([^\s]+)$/i.exec(authorization);
  const token = bearer?.[1];
  if (!token) return json(401, { error: "AUTHENTICATION_REQUIRED" });

  let body: Record<string, unknown>;
  try {
    const parsed: unknown = await req.json();
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      return json(400, { error: "INVALID_JSON_OBJECT" });
    }
    body = parsed as Record<string, unknown>;
  } catch {
    return json(400, { error: "INVALID_JSON" });
  }

  const assetId = typeof body.asset_id === "string" ? body.asset_id.trim() : "";
  const decision = typeof body.decision === "string" ? body.decision : "";
  const rationale = typeof body.rationale === "string" ? body.rationale.trim() : "";

  if (!UUID.test(assetId) ||
      !["accept_evidence", "reject"].includes(decision) ||
      rationale.length < 10 ||
      rationale.length > 2000) {
    return json(400, { error: "ASSET_DECISION_OR_RATIONALE_INVALID" });
  }

  const url = Deno.env.get("SUPABASE_URL");
  const publishable = Deno.env.get("SUPABASE_PUBLISHABLE_KEY") ??
    Deno.env.get("SUPABASE_ANON_KEY");
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !publishable || !service) {
    return json(503, { error: "FUNCTION_CONFIG_MISSING" });
  }

  try {
    const authResponse = await fetch(url + "/auth/v1/user", {
      headers: { apikey: publishable, Authorization: "Bearer " + token },
      signal: AbortSignal.timeout(12_000),
    });
    if (!authResponse.ok) return json(401, { error: "INVALID_SESSION" });

    const user = await authResponse.json() as { id?: string };
    if (!user.id || !UUID.test(user.id)) return json(401, { error: "INVALID_SESSION" });

    const profileUrl = new URL(url + "/rest/v1/profiles");
    profileUrl.searchParams.set("select", "role");
    profileUrl.searchParams.set("id", "eq." + user.id);

    const profileResponse = await fetch(profileUrl, {
      headers: { apikey: service, Authorization: "Bearer " + service },
      signal: AbortSignal.timeout(12_000),
    });
    if (!profileResponse.ok) return json(503, { error: "PROFILE_LOOKUP_FAILED" });

    const profiles = await profileResponse.json() as Array<{ role: string }>;
    const role = profiles[0]?.role ?? "";
    if (role !== "admin" && role !== "coordinator") {
      return json(403, { error: "REVIEWER_ROLE_REQUIRED" });
    }

    const rpcResponse = await fetch(url + "/rest/v1/rpc/review_underground_asset_submission", {
      method: "POST",
      headers: {
        apikey: service,
        Authorization: "Bearer " + service,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        p_actor_id: user.id,
        p_asset_id: assetId,
        p_decision: decision,
        p_rationale: rationale,
      }),
      signal: AbortSignal.timeout(20_000),
    });

    if (!rpcResponse.ok) {
      return json(409, {
        error: "REVIEW_NOT_COMPLETED",
        detail: "The submission may lack required evidence or may no longer be reviewable.",
      });
    }

    const result = await rpcResponse.json() as Record<string, unknown>;
    return json(200, result);
  } catch {
    return json(502, { error: "REVIEW_SERVICE_UNAVAILABLE" });
  }
});
