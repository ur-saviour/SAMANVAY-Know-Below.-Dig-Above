import "jsr:@supabase/functions-js/edge-runtime.d.ts";

type Json = Record<string, unknown>;
const BUCKET = "samanvay-case-evidence";
const MAX_BYTES = 20 * 1024 * 1024;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const SHA256 = /^[0-9a-f]{64}$/i;
const ALLOWED_TYPES = new Set([
  "site_photo", "survey_evidence", "permit", "drawing", "inspection_report", "other",
]);
const ALLOWED_MIME = new Set(["application/pdf", "image/jpeg", "image/png", "image/webp"]);
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function reply(status: number, body: Json): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}
function env() {
  const url = Deno.env.get("SUPABASE_URL");
  const publicKey = Deno.env.get("SUPABASE_ANON_KEY") ??
    Deno.env.get("SUPABASE_PUBLISHABLE_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !publicKey || !serviceKey) throw new Error("FUNCTION_CONFIG_MISSING");
  return { url, publicKey, serviceKey };
}
function cleanText(value: unknown, min: number, max: number): string | null {
  if (typeof value !== "string") return null;
  const result = value.trim();
  return result.length >= min && result.length <= max ? result : null;
}
function isoTimestamp(value: unknown): string | null {
  if (typeof value !== "string" || value.length > 50) return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}
function sniffMime(bytes: Uint8Array): string | null {
  if (bytes.length >= 5 &&
      bytes[0] === 0x25 && bytes[1] === 0x50 && bytes[2] === 0x44 &&
      bytes[3] === 0x46 && bytes[4] === 0x2d) return "application/pdf";
  if (bytes.length >= 3 &&
      bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return "image/jpeg";
  if (bytes.length >= 8 &&
      bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e &&
      bytes[3] === 0x47 && bytes[4] === 0x0d && bytes[5] === 0x0a &&
      bytes[6] === 0x1a && bytes[7] === 0x0a) return "image/png";
  if (bytes.length >= 12 &&
      String.fromCharCode(...bytes.slice(0, 4)) === "RIFF" &&
      String.fromCharCode(...bytes.slice(8, 12)) === "WEBP") return "image/webp";
  return null;
}
async function sha256(bytes: Uint8Array): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((value) => value.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (request.method !== "POST") return reply(405, { error: "METHOD_NOT_ALLOWED" });

  const token = (request.headers.get("Authorization") ?? "")
    .match(/^Bearer\s+(.+)$/i)?.[1];
  if (!token) return reply(401, { error: "AUTHENTICATION_REQUIRED" });

  let body: Json;
  try {
    const raw = await request.text();
    if (new TextEncoder().encode(raw).length > 12000) {
      return reply(413, { error: "REQUEST_TOO_LARGE" });
    }
    body = JSON.parse(raw) as Json;
  } catch {
    return reply(400, { error: "INVALID_JSON" });
  }

  let config: ReturnType<typeof env>;
  try {
    config = env();
  } catch {
    return reply(503, { error: "FUNCTION_CONFIG_MISSING" });
  }

  // Resolve the caller from the bearer token; never accept a client-supplied
  // uploader ID or role.
  let userId: string;
  try {
    const auth = await fetch(config.url + "/auth/v1/user", {
      headers: { apikey: config.publicKey, Authorization: "Bearer " + token },
      signal: AbortSignal.timeout(12000),
    });
    if (!auth.ok) return reply(401, { error: "INVALID_SESSION" });
    const user = await auth.json() as { id?: string };
    if (!user.id || !UUID.test(user.id)) return reply(401, { error: "INVALID_SESSION" });
    userId = user.id;
  } catch {
    return reply(503, { error: "AUTHENTICATION_CHECK_UNAVAILABLE" });
  }

  const requestId = typeof body.request_id === "string" ? body.request_id : "";
  const storagePath = typeof body.storage_path === "string" ? body.storage_path.trim() : "";
  const fileName = cleanText(body.file_name, 1, 200);
  const declaredMime = cleanText(body.content_type, 1, 80)?.toLowerCase() ?? "";
  const attachmentType = cleanText(body.attachment_type, 1, 40);
  const parts = storagePath.split("/");
  const validObjectPath = UUID.test(requestId) &&
    parts.length === 3 && parts[0] === requestId && parts[1] === userId &&
    /^[A-Za-z0-9._-]{1,180}$/.test(parts[2] ?? "");
  if (!validObjectPath || !fileName || !ALLOWED_MIME.has(declaredMime) ||
      !attachmentType || !ALLOWED_TYPES.has(attachmentType)) {
    return reply(400, { error: "ATTACHMENT_METADATA_INVALID" });
  }

  const inspectionId = body.inspection_id === null || body.inspection_id === undefined
    ? null : (typeof body.inspection_id === "string" ? body.inspection_id : "");
  if (inspectionId !== null && !UUID.test(inspectionId)) {
    return reply(400, { error: "INSPECTION_REFERENCE_INVALID" });
  }
  const capturedAt = body.captured_at === null || body.captured_at === undefined
    ? null : isoTimestamp(body.captured_at);
  if (body.captured_at !== null && body.captured_at !== undefined && !capturedAt) {
    return reply(400, { error: "CAPTURE_TIMESTAMP_INVALID" });
  }

  const lat = body.captured_latitude;
  const lon = body.captured_longitude;
  const accuracy = body.location_accuracy_m;
  const hasLocation = lat !== null && lat !== undefined ||
    lon !== null && lon !== undefined || accuracy !== null && accuracy !== undefined;
  if (hasLocation && !(typeof lat === "number" && Number.isFinite(lat) &&
      lat >= -90 && lat <= 90 && typeof lon === "number" &&
      Number.isFinite(lon) && lon >= -180 && lon <= 180 &&
      typeof accuracy === "number" && Number.isFinite(accuracy) &&
      accuracy >= 0 && accuracy <= 10000)) {
    return reply(400, { error: "CAPTURE_LOCATION_INVALID" });
  }
  if ((capturedAt !== null || hasLocation) && inspectionId === null) {
    return reply(400, { error: "INSPECTION_LINK_REQUIRED_FOR_CAPTURE_METADATA" });
  }

  // Fetch the exact private object using a server credential, then independently
  // inspect its real MIME type, byte length and checksum.
  const objectUrl = config.url + "/storage/v1/object/authenticated/" + BUCKET + "/" +
    parts.map((part) => encodeURIComponent(part)).join("/");
  let objectResponse: Response;
  try {
    objectResponse = await fetch(objectUrl, {
      headers: { apikey: config.serviceKey, Authorization: "Bearer " + config.serviceKey },
      signal: AbortSignal.timeout(25000),
    });
  } catch {
    return reply(503, { error: "EVIDENCE_OBJECT_CHECK_UNAVAILABLE" });
  }
  if (!objectResponse.ok) return reply(409, { error: "EVIDENCE_OBJECT_NOT_ACCESSIBLE" });

  const bytes = new Uint8Array(await objectResponse.arrayBuffer());
  if (bytes.length < 1 || bytes.length > MAX_BYTES) {
    return reply(413, { error: "EVIDENCE_FILE_SIZE_INVALID" });
  }
  const actualMime = sniffMime(bytes);
  if (!actualMime || actualMime !== declaredMime) {
    return reply(415, { error: "EVIDENCE_FILE_CONTENT_TYPE_MISMATCH" });
  }
  const checksum = await sha256(bytes);

  // Perform the metadata insert with the caller's own JWT so table RLS remains
  // the authority for case participation and inspection ownership.
  const insertUrl = config.url + "/rest/v1/case_attachments?select=id";
  const insertBody: Json = {
    request_id: requestId,
    storage_path: storagePath,
    file_name: fileName,
    content_type: actualMime,
    file_size_bytes: bytes.length,
    attachment_type: attachmentType,
    uploaded_by: userId,
    sha256: checksum,
  };
  if (inspectionId !== null) insertBody.inspection_id = inspectionId;
  if (capturedAt !== null) insertBody.captured_at = capturedAt;
  if (hasLocation) {
    insertBody.captured_latitude = lat;
    insertBody.captured_longitude = lon;
    insertBody.location_accuracy_m = accuracy;
  }

  try {
    const inserted = await fetch(insertUrl, {
      method: "POST",
      headers: {
        apikey: config.publicKey,
        Authorization: "Bearer " + token,
        "Content-Type": "application/json",
        Prefer: "return=representation",
      },
      body: JSON.stringify(insertBody),
      signal: AbortSignal.timeout(20000),
    });
    if (!inserted.ok) {
      // Do not reveal request existence or RLS policy details to unauthorised callers.
      return reply(inserted.status === 401 ? 401 : 403, {
        error: "ATTACHMENT_NOT_AUTHORISED_OR_NOT_RECORDED",
      });
    }
    const rows = await inserted.json() as Array<{ id?: string }>;
    const attachmentId = rows[0]?.id;
    if (!attachmentId) return reply(500, { error: "ATTACHMENT_RECORD_NOT_RETURNED" });
    return reply(200, {
      ok: true,
      attachment_id: attachmentId,
      sha256: checksum,
      file_size_bytes: bytes.length,
      content_type: actualMime,
    });
  } catch {
    return reply(503, { error: "ATTACHMENT_REGISTRATION_UNAVAILABLE" });
  }
});
