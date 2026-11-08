import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
type Json = Record<string, unknown>;

const ASSET_TYPES = new Set(["water", "sewer", "stormwater", "electricity", "telecom", "gas", "borewell", "drain", "other", "unknown"]);
const SOURCE_TYPES = new Set(["utility_owner", "field_survey", "as_built_drawing"]);
const GEOMETRY_TYPES = new Set(["Point", "MultiPoint", "LineString", "MultiLineString"]);
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const MAX_BODY_BYTES = 10 * 1024 * 1024;
const MAX_FEATURE_BYTES = 512 * 1024;
const MAX_COORDINATES_PER_FEATURE = 20000;

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

function requiredString(value: unknown, field: string, min: number, max: number): string {
  if (typeof value !== "string") throw new Error(field + "_REQUIRED");
  const result = value.trim();
  if (result.length < min || result.length > max) throw new Error(field + "_LENGTH_INVALID");
  return result;
}

function optionalString(value: unknown, field: string, max: number): string | null {
  if (value === undefined || value === null || value === "") return null;
  if (typeof value !== "string" || value.trim().length > max) throw new Error(field + "_INVALID");
  return value.trim() || null;
}

function optionalNumber(value: unknown, field: string, min: number, max: number): number | null {
  if (value === null || value === undefined || value === "") return null;
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed < min || parsed > max) throw new Error(field + "_OUT_OF_RANGE");
  return parsed;
}

function inspectCoordinates(value: unknown, depth = 0): number {
  if (depth > 12 || !Array.isArray(value) || value.length === 0) throw new Error("INVALID_GEOJSON_COORDINATES");
  if (typeof value[0] === "number" || typeof value[1] === "number") {
    if (value.length !== 2 || typeof value[0] !== "number" || typeof value[1] !== "number") {
      throw new Error("ONLY_2D_WGS84_COORDINATES_ARE_ACCEPTED");
    }
    const lon = value[0], lat = value[1];
    if (!Number.isFinite(lon) || !Number.isFinite(lat) || lon < -180 || lon > 180 || lat < -90 || lat > 90) {
      throw new Error("COORDINATES_OUTSIDE_WGS84_BOUNDS");
    }
    return 1;
  }
  let count = 0;
  for (const child of value) {
    count += inspectCoordinates(child, depth + 1);
    if (count > MAX_COORDINATES_PER_FEATURE) throw new Error("FEATURE_COORDINATE_LIMIT_EXCEEDED");
  }
  return count;
}

type ImportSource = {
  source_title: string;
  source_organisation: string;
  source_type: "utility_owner" | "field_survey" | "as_built_drawing";
  authorization_reference: string;
  data_sharing_basis: string;
  source_url: string | null;
  declared_srid: 4326;
};

function validateSource(value: unknown): ImportSource {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error("SOURCE_METADATA_REQUIRED");
  const source = value as Json;
  const sourceType = String(source.source_type ?? "").trim().toLowerCase();
  if (!SOURCE_TYPES.has(sourceType)) throw new Error("SOURCE_TYPE_MUST_BE_OWNER_AUTHORISED_OR_SURVEYED");
  const srid = Number(source.declared_srid);
  if (srid !== 4326) throw new Error("ONLY_EPSG_4326_LONGITUDE_LATITUDE_IS_ACCEPTED");
  const sourceUrl = optionalString(source.source_url, "SOURCE_URL", 1000);
  if (sourceUrl !== null) {
    let parsed: URL;
    try { parsed = new URL(sourceUrl); } catch { throw new Error("SOURCE_URL_INVALID"); }
    if (parsed.protocol !== "https:") throw new Error("SOURCE_URL_MUST_USE_HTTPS");
  }
  return {
    source_title: requiredString(source.source_title, "SOURCE_TITLE", 3, 200),
    source_organisation: requiredString(source.source_organisation, "SOURCE_ORGANISATION", 3, 200),
    source_type: sourceType as ImportSource["source_type"],
    authorization_reference: requiredString(source.authorization_reference, "AUTHORIZATION_REFERENCE", 6, 200),
    data_sharing_basis: requiredString(source.data_sharing_basis, "DATA_SHARING_BASIS", 10, 1000),
    source_url: sourceUrl,
    declared_srid: 4326,
  };
}

function validateFeature(feature: unknown, source: ImportSource): Json {
  if (!feature || typeof feature !== "object" || Array.isArray(feature)) throw new Error("FEATURE_MUST_BE_OBJECT");
  const f = feature as Json;
  if (f.type !== "Feature" || !f.geometry || typeof f.geometry !== "object" || Array.isArray(f.geometry)) {
    throw new Error("GEOJSON_FEATURE_AND_GEOMETRY_REQUIRED");
  }
  if (!f.properties || typeof f.properties !== "object" || Array.isArray(f.properties)) {
    throw new Error("FEATURE_PROPERTIES_REQUIRED");
  }
  if (new TextEncoder().encode(JSON.stringify(f)).length > MAX_FEATURE_BYTES) throw new Error("FEATURE_SIZE_LIMIT_EXCEEDED");

  const geometry = f.geometry as Json;
  const props = f.properties as Json;
  const geometryType = String(geometry.type ?? "");
  if (!GEOMETRY_TYPES.has(geometryType)) throw new Error("UNSUPPORTED_GEOMETRY_TYPE");
  const coordinateCount = inspectCoordinates(geometry.coordinates);
  if (coordinateCount < 1 || coordinateCount > MAX_COORDINATES_PER_FEATURE) throw new Error("FEATURE_COORDINATE_LIMIT_EXCEEDED");

  const code = requiredString(props.asset_code, "ASSET_CODE", 2, 100);
  const name = requiredString(props.asset_name, "ASSET_NAME", 2, 200);
  const assetType = String(props.asset_type ?? "").trim().toLowerCase();
  if (!ASSET_TYPES.has(assetType)) throw new Error("UNSUPPORTED_ASSET_TYPE");

  const surveyedAt = optionalString(props.surveyed_at, "SURVEYED_AT", 50);
  if (surveyedAt !== null && Number.isNaN(Date.parse(surveyedAt))) throw new Error("SURVEYED_AT_INVALID");
  if (source.source_type === "field_survey" && surveyedAt === null) throw new Error("FIELD_SURVEY_DATE_REQUIRED");

  const material = optionalString(props.material, "MATERIAL", 100);
  const diameter = optionalNumber(props.diameter_mm, "DIAMETER_MM", Number.MIN_VALUE, 10000);
  return {
    type: "Feature",
    geometry,
    properties: {
      asset_code: code,
      asset_name: name,
      asset_type: assetType,
      source_type: source.source_type,
      source_reference: source.authorization_reference,
      surveyed_by_org: source.source_organisation,
      surveyed_at: surveyedAt,
      depth_m: optionalNumber(props.depth_m, "DEPTH_M", 0, 100),
      horizontal_accuracy_m: optionalNumber(props.horizontal_accuracy_m, "HORIZONTAL_ACCURACY_M", 0, 1000),
      vertical_accuracy_m: optionalNumber(props.vertical_accuracy_m, "VERTICAL_ACCURACY_M", 0, 1000),
      material,
      diameter_mm: diameter,
      verification_notes: null,
    },
  };
}

function sha256Hex(bytes: Uint8Array): Promise<string> {
  return crypto.subtle.digest("SHA-256", bytes).then((digest) =>
    Array.from(new Uint8Array(digest)).map((value) => value.toString(16).padStart(2, "0")).join("")
  );
}

async function registerBatch(config: ReturnType<typeof keys>, actorId: string, assets: Json[], runId: string): Promise<Json> {
  const response = await fetch(config.url + "/rest/v1/rpc/register_underground_assets_batch_server", {
    method: "POST",
    headers: {
      apikey: config.secret,
      Authorization: "Bearer " + config.secret,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ p_actor_id: actorId, p_assets: assets, p_import_run_id: runId }),
    signal: AbortSignal.timeout(60000),
  });
  if (!response.ok) {
    // Do not propagate provider/database diagnostics to mobile clients.
    throw new Error("BATCH_REGISTRATION_FAILED");
  }
  return await response.json() as Json;
}

async function createAuditRun(config: ReturnType<typeof keys>, payload: Json): Promise<string> {
  const response = await fetch(config.url + "/rest/v1/utility_geometry_import_runs?select=id", {
    method: "POST",
    headers: {
      apikey: config.secret,
      Authorization: "Bearer " + config.secret,
      "Content-Type": "application/json",
      Prefer: "return=representation",
    },
    body: JSON.stringify(payload),
    signal: AbortSignal.timeout(15000),
  });
  if (!response.ok) throw new Error("IMPORT_AUDIT_CREATE_FAILED");
  const rows = await response.json() as Array<{ id?: string }>;
  if (!Array.isArray(rows) || !rows[0]?.id || !UUID.test(rows[0].id)) throw new Error("IMPORT_AUDIT_ID_MISSING");
  return rows[0].id;
}

async function updateAuditRun(config: ReturnType<typeof keys>, runId: string, patch: Json): Promise<void> {
  const url = new URL(config.url + "/rest/v1/utility_geometry_import_runs");
  url.searchParams.set("id", "eq." + runId);
  const response = await fetch(url, {
    method: "PATCH",
    headers: {
      apikey: config.secret,
      Authorization: "Bearer " + config.secret,
      "Content-Type": "application/json",
      Prefer: "return=minimal",
    },
    body: JSON.stringify(patch),
    signal: AbortSignal.timeout(15000),
  });
  if (!response.ok) throw new Error("IMPORT_AUDIT_UPDATE_FAILED");
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json(405, { error: "METHOD_NOT_ALLOWED" });

  const authHeader = request.headers.get("Authorization") ?? "";
  const token = authHeader.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!token) return json(401, { error: "AUTHENTICATION_REQUIRED" });

  let rawBody: string;
  let body: Json;
  let bodyBytes: Uint8Array;
  try {
    rawBody = await request.text();
    bodyBytes = new TextEncoder().encode(rawBody);
    if (bodyBytes.byteLength > MAX_BODY_BYTES) return json(413, { error: "REQUEST_EXCEEDS_10_MB" });
    body = JSON.parse(rawBody) as Json;
  } catch {
    return json(400, { error: "INVALID_OR_OVERSIZED_JSON" });
  }
  if (!body || typeof body !== "object" || Array.isArray(body) || body.action !== "import" || !Array.isArray(body.features)) {
    return json(400, { error: "IMPORT_FEATURE_COLLECTION_REQUIRED" });
  }
  const features = body.features;
  if (features.length === 0 || features.length > 500) return json(400, { error: "BATCH_MUST_CONTAIN_1_TO_500_FEATURES" });

  let config: ReturnType<typeof keys>;
  let source: ImportSource;
  try {
    config = keys();
    source = validateSource(body.source);
  } catch (error) {
    return json(400, { error: error instanceof Error ? error.message : "SOURCE_METADATA_INVALID" });
  }

  const authResponse = await fetch(config.url + "/auth/v1/user", {
    headers: { apikey: config.publishable, Authorization: "Bearer " + token },
    signal: AbortSignal.timeout(15000),
  });
  if (!authResponse.ok) return json(401, { error: "INVALID_SESSION" });
  const authUser = await authResponse.json() as { id?: string };
  if (!authUser.id || !UUID.test(authUser.id)) return json(401, { error: "INVALID_SESSION" });

  const profileUrl = new URL(config.url + "/rest/v1/profiles");
  profileUrl.searchParams.set("select", "id,role,department_id");
  profileUrl.searchParams.set("id", "eq." + authUser.id);
  const profileResponse = await fetch(profileUrl, {
    headers: { apikey: config.secret, Authorization: "Bearer " + config.secret, Accept: "application/json" },
    signal: AbortSignal.timeout(15000),
  });
  if (!profileResponse.ok) return json(503, { error: "PROFILE_LOOKUP_FAILED" });
  const profiles = await profileResponse.json() as Array<{ id: string; role: string; department_id: string | null }>;
  const profile = profiles[0];
  if (!profile || profile.role !== "department" || !profile.department_id || !UUID.test(profile.department_id)) {
    return json(403, { error: "ASSIGNED_DEPARTMENT_ACCOUNT_REQUIRED" });
  }

  const payloadHash = await sha256Hex(bodyBytes);
  const seen = new Set<string>();
  const prepared: Json[] = [];
  let validationRejected = 0;
  for (const feature of features) {
    try {
      const normalised = validateFeature(feature, source);
      const props = normalised.properties as Json;
      const code = String(props.asset_code);
      if (seen.has(code)) throw new Error("DUPLICATE_ASSET_CODE_IN_BATCH");
      seen.add(code);
      prepared.push(normalised);
    } catch {
      validationRejected++;
    }
  }

  let runId: string;
  try {
    runId = await createAuditRun(config, {
      owner_department_id: profile.department_id,
      requested_by: authUser.id,
      source_title: source.source_title,
      source_organisation: source.source_organisation,
      source_type: source.source_type,
      authorization_reference: source.authorization_reference,
      data_sharing_basis: source.data_sharing_basis,
      source_url: source.source_url,
      declared_srid: source.declared_srid,
      payload_sha256: payloadHash,
      received_features: features.length,
      status: "importing",
    });
  } catch {
    return json(503, { error: "IMPORT_AUDIT_UNAVAILABLE_NO_ASSETS_IMPORTED" });
  }

  let imported = 0;
  let rejected = validationRejected;
  let status = "failed";
  let auditError = "All records were rejected by server-side validation.";
  try {
    if (prepared.length > 0) {
      const result = await registerBatch(config, authUser.id, prepared, runId);
      const batchImported = Number(result.imported ?? 0);
      const batchFailed = Number(result.failed ?? 0);
      if (!Number.isSafeInteger(batchImported) || !Number.isSafeInteger(batchFailed) ||
          batchImported < 0 || batchFailed < 0 || batchImported + batchFailed !== prepared.length) {
        throw new Error("BATCH_RESULT_NOT_RECONCILED");
      }
      imported = batchImported;
      rejected += batchFailed;
      status = imported === 0 ? "failed" : rejected === 0 ? "imported_pending_review" : "partially_imported";
      auditError = rejected > 0 ? "One or more features were rejected; review the source file and resubmit corrected features." : "";
    }
    await updateAuditRun(config, runId, {
      imported_features: imported,
      rejected_features: rejected,
      status,
      error_summary: auditError || null,
      completed_at: new Date().toISOString(),
    });
  } catch {
    // The run is marked failed/uncertain rather than returning any asset identifiers or geometry.
    status = imported > 0 ? "partially_imported" : "failed";
    rejected = Math.max(rejected, features.length - imported);
    try {
      await updateAuditRun(config, runId, {
        imported_features: imported,
        rejected_features: rejected,
        status,
        error_summary: "Registration outcome could not be fully confirmed. Reconcile this import run before retrying.",
        completed_at: new Date().toISOString(),
      });
    } catch {
      // The audit row remains visible to service-role reconciliation.
    }
    return json(502, {
      ok: false,
      run_id: runId,
      received: features.length,
      imported,
      rejected,
      verification_status: "unverified",
      map_visibility: "hidden_pending_review",
      error: "IMPORT_RESULT_REQUIRES_RECONCILIATION",
    });
  }

  return json(200, {
    ok: imported === features.length,
    run_id: runId,
    received: features.length,
    imported,
    rejected,
    verification_status: "unverified",
    map_visibility: "hidden_pending_review",
    note: "Source metadata is a submitter declaration, not independent proof of authority. A separate owner review is required before any asset can be treated as verified.",
  });
});
