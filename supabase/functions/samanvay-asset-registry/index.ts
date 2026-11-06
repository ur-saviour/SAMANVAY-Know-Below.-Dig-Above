import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type Json = Record<string, unknown>;
const ASSET_TYPES = new Set(["water", "sewer", "stormwater", "electricity", "telecom", "gas", "borewell", "drain", "other", "unknown"]);
const SOURCE_TYPES = new Set(["utility_owner", "field_survey", "as_built_drawing", "public_dataset", "estimated", "other"]);
const GEOMETRY_TYPES = new Set(["Point", "MultiPoint", "LineString", "MultiLineString"]);
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function json(status: number, body: Json): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function secretMap(name: string): Record<string, string> {
  const raw = Deno.env.get(name);
  if (!raw) return {};
  try {
    const value = JSON.parse(raw);
    return value && typeof value === "object" ? value as Record<string, string> : {};
  } catch {
    return {};
  }
}

function keys() {
  const url = Deno.env.get("SUPABASE_URL");
  const publishable = Deno.env.get("SUPABASE_ANON_KEY") ?? secretMap("SUPABASE_PUBLISHABLE_KEYS")["default"];
  const secret = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? secretMap("SUPABASE_SECRET_KEYS")["default"];
  if (!url || !publishable || !secret) throw new Error("SUPABASE_FUNCTION_CONFIG_MISSING");
  return { url, publishable, secret };
}

function validCoordinates(value: unknown): boolean {
  if (!Array.isArray(value) || value.length === 0) return false;
  if (typeof value[0] === "number" && typeof value[1] === "number") {
    const lon = value[0], lat = value[1];
    return Number.isFinite(lon) && Number.isFinite(lat) && lon >= -180 && lon <= 180 && lat >= -90 && lat <= 90;
  }
  return value.every(validCoordinates);
}

function optionalNumber(value: unknown, field: string, min: number, max: number): number | null {
  if (value === null || value === undefined || value === "") return null;
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed < min || parsed > max) throw new Error(field + "_OUT_OF_RANGE");
  return parsed;
}

function validateFeature(feature: unknown): { props: Json; geometry: Json } {
  if (!feature || typeof feature !== "object") throw new Error("FEATURE_MUST_BE_OBJECT");
  const f = feature as Json;
  if (!f.geometry || typeof f.geometry !== "object" || !f.properties || typeof f.properties !== "object") {
    throw new Error("GEOMETRY_AND_PROPERTIES_REQUIRED");
  }
  const geometry = f.geometry as Json;
  const props = f.properties as Json;
  const geometryType = String(geometry.type ?? "");
  if (!GEOMETRY_TYPES.has(geometryType)) throw new Error("UNSUPPORTED_GEOMETRY_TYPE");
  if (!validCoordinates(geometry.coordinates)) throw new Error("INVALID_WGS84_COORDINATES_LONGITUDE_LATITUDE");
  const code = String(props.asset_code ?? "").trim();
  const name = String(props.asset_name ?? "").trim();
  const assetType = String(props.asset_type ?? "").trim().toLowerCase();
  const sourceType = String(props.source_type ?? "").trim().toLowerCase();
  if (code.length < 2 || code.length > 100) throw new Error("ASSET_CODE_MUST_BE_2_TO_100_CHARACTERS");
  if (name.length < 2 || name.length > 200) throw new Error("ASSET_NAME_MUST_BE_2_TO_200_CHARACTERS");
  if (!ASSET_TYPES.has(assetType)) throw new Error("UNSUPPORTED_ASSET_TYPE");
  if (!SOURCE_TYPES.has(sourceType)) throw new Error("UNSUPPORTED_SOURCE_TYPE");
  optionalNumber(props.depth_m, "DEPTH_M", 0, 100);
  optionalNumber(props.horizontal_accuracy_m, "HORIZONTAL_ACCURACY_M", 0, 1000);
  optionalNumber(props.vertical_accuracy_m, "VERTICAL_ACCURACY_M", 0, 1000);
  optionalNumber(props.diameter_mm, "DIAMETER_MM", Number.MIN_VALUE, 10000);
  return { props: { ...props, asset_code: code, asset_name: name, asset_type: assetType, source_type: sourceType }, geometry };
}

async function registerAsset(config: ReturnType<typeof keys>, actorId: string, props: Json, geometry: Json): Promise<string> {
  const surveyedAtRaw = props.surveyed_at == null ? null : String(props.surveyed_at).trim();
  const surveyedAt = surveyedAtRaw ? new Date(surveyedAtRaw) : null;
  if (surveyedAt && Number.isNaN(surveyedAt.getTime())) throw new Error("INVALID_SURVEYED_AT");
  const payload = {
    p_actor_id: actorId,
    p_asset_code: props.asset_code,
    p_asset_name: props.asset_name,
    p_asset_type: props.asset_type,
    p_geometry: geometry,
    p_source_type: props.source_type,
    p_source_reference: props.source_reference == null ? null : String(props.source_reference),
    p_depth_m: optionalNumber(props.depth_m, "DEPTH_M", 0, 100),
    p_horizontal_accuracy_m: optionalNumber(props.horizontal_accuracy_m, "HORIZONTAL_ACCURACY_M", 0, 1000),
    p_vertical_accuracy_m: optionalNumber(props.vertical_accuracy_m, "VERTICAL_ACCURACY_M", 0, 1000),
    p_material: props.material == null ? null : String(props.material).slice(0, 120),
    p_diameter_mm: optionalNumber(props.diameter_mm, "DIAMETER_MM", Number.MIN_VALUE, 10000),
    p_surveyed_at: surveyedAt?.toISOString() ?? null,
    p_surveyed_by_org: props.surveyed_by_org == null ? null : String(props.surveyed_by_org).slice(0, 200),
    p_verification_notes: props.verification_notes == null ? null : String(props.verification_notes).slice(0, 2000),
  };
  const response = await fetch(config.url + "/rest/v1/rpc/register_underground_asset_server", {
    method: "POST",
    headers: {
      apikey: config.secret,
      Authorization: "Bearer " + config.secret,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });
  if (!response.ok) {
    const detail = await response.text();
    if (response.status === 409 || detail.toLowerCase().includes("duplicate")) throw new Error("ASSET_CODE_ALREADY_EXISTS");
    throw new Error("DATABASE_REGISTRATION_FAILED_" + response.status);
  }
  const result = await response.json();
  return String(result);
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json(405, { error: "METHOD_NOT_ALLOWED" });
  const authHeader = request.headers.get("Authorization") ?? "";
  const token = authHeader.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!token) return json(401, { error: "AUTHENTICATION_REQUIRED" });
  const contentLength = Number(request.headers.get("content-length") ?? "0");
  if (contentLength > 10 * 1024 * 1024) return json(413, { error: "REQUEST_EXCEEDS_10_MB" });

  let body: Json;
  try {
    body = await request.json() as Json;
  } catch {
    return json(400, { error: "INVALID_JSON" });
  }
  if (body.action !== "import" || !Array.isArray(body.features)) return json(400, { error: "IMPORT_FEATURE_COLLECTION_REQUIRED" });
  const features = body.features;
  if (features.length === 0 || features.length > 500) return json(400, { error: "BATCH_MUST_CONTAIN_1_TO_500_FEATURES" });

  let config: ReturnType<typeof keys>;
  try {
    config = keys();
  } catch {
    return json(503, { error: "SUPABASE_FUNCTION_CONFIG_MISSING" });
  }

  const authResponse = await fetch(config.url + "/auth/v1/user", {
    headers: { apikey: config.publishable, Authorization: "Bearer " + token },
  });
  if (!authResponse.ok) return json(401, { error: "INVALID_SESSION" });
  const authUser = await authResponse.json() as { id?: string };
  if (!authUser.id || !UUID.test(authUser.id)) return json(401, { error: "INVALID_SESSION" });

  const profileUrl = new URL(config.url + "/rest/v1/profiles");
  profileUrl.searchParams.set("select", "id,role,department_id");
  profileUrl.searchParams.set("id", "eq." + authUser.id);
  const profileResponse = await fetch(profileUrl, {
    headers: { apikey: config.secret, Authorization: "Bearer " + config.secret, Accept: "application/json" },
  });
  if (!profileResponse.ok) return json(503, { error: "PROFILE_LOOKUP_FAILED" });
  const profiles = await profileResponse.json() as Array<{ id: string; role: string; department_id: string | null }>;
  const profile = profiles[0];
  if (!profile || profile.role !== "department" || !profile.department_id) {
    return json(403, { error: "ASSIGNED_DEPARTMENT_ACCOUNT_REQUIRED" });
  }

  const seen = new Set<string>();
  const results: Array<{ asset_code: string; id?: string; error?: string }> = [];
  let imported = 0;
  for (let i = 0; i < features.length; i++) {
    try {
      const { props, geometry } = validateFeature(features[i]);
      const code = String(props.asset_code);
      if (seen.has(code)) throw new Error("DUPLICATE_ASSET_CODE_IN_BATCH");
      seen.add(code);
      const id = await registerAsset(config, authUser.id, props, geometry);
      imported++;
      results.push({ asset_code: code, id });
    } catch (error) {
      const raw = error instanceof Error ? error.message : "UNKNOWN_IMPORT_ERROR";
      results.push({ asset_code: "feature_" + (i + 1), error: raw.slice(0, 180) });
    }
  }

  return json(200, {
    ok: imported === features.length,
    department_id: profile.department_id,
    received: features.length,
    imported,
    failed: features.length - imported,
    verification_status: "unverified",
    results,
  });
});
