import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type BoundaryLevel = "ADM1" | "ADM2";
type BoundaryMetadata = Record<string, unknown>;
const cache = new Map<BoundaryLevel, { expiresAt: number; payload: Record<string, unknown> }>();
const CACHE_TTL_MS = 6 * 60 * 60 * 1000;
const MAX_GEOJSON_BYTES = 12 * 1024 * 1024;

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      "Cache-Control": "private, max-age=300",
    },
  });
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return json(405, { error: "METHOD_NOT_ALLOWED" });
  }

  let body: { level?: unknown };
  try {
    body = await request.json();
  } catch {
    return json(400, { error: "INVALID_JSON" });
  }
  const level = body.level;
  if (level !== "ADM1" && level !== "ADM2") {
    return json(400, { error: "UNSUPPORTED_BOUNDARY_LEVEL" });
  }
  const boundaryLevel = level as BoundaryLevel;

  const cached = cache.get(boundaryLevel);
  if (cached && cached.expiresAt > Date.now()) {
    return json(200, cached.payload);
  }

  try {
    const metadataUrl = "https://www.geoboundaries.org/api/current/gbOpen/IND/" + boundaryLevel + "/";
    const metadataResponse = await fetch(metadataUrl, {
      headers: { Accept: "application/json" },
      signal: AbortSignal.timeout(20000),
    });
    if (!metadataResponse.ok) {
      return json(502, { error: "BOUNDARY_METADATA_UNAVAILABLE", provider_status: metadataResponse.status });
    }
    const metadata = await metadataResponse.json() as BoundaryMetadata;
    if (metadata.boundaryISO !== "IND" || metadata.boundaryType !== boundaryLevel) {
      return json(502, { error: "BOUNDARY_METADATA_MISMATCH" });
    }

    const geoJsonUrl = String(metadata.simplifiedGeometryGeoJSON ?? metadata.gjDownloadURL ?? "");
    let parsedUrl: URL;
    try {
      parsedUrl = new URL(geoJsonUrl);
    } catch {
      return json(502, { error: "BOUNDARY_DOWNLOAD_URL_INVALID" });
    }
    if (parsedUrl.protocol !== "https:" ||
        !["github.com", "raw.githubusercontent.com"].includes(parsedUrl.hostname)) {
      return json(502, { error: "BOUNDARY_DOWNLOAD_HOST_NOT_ALLOWED" });
    }

    const geoResponse = await fetch(parsedUrl, {
      headers: { Accept: "application/geo+json, application/json" },
      signal: AbortSignal.timeout(30000),
    });
    if (!geoResponse.ok) {
      return json(502, { error: "BOUNDARY_GEOJSON_UNAVAILABLE", provider_status: geoResponse.status });
    }
    const geoJsonText = await geoResponse.text();
    if (new TextEncoder().encode(geoJsonText).byteLength > MAX_GEOJSON_BYTES) {
      return json(413, { error: "BOUNDARY_GEOJSON_TOO_LARGE" });
    }
    const geojson = JSON.parse(geoJsonText) as Record<string, unknown>;
    const features = geojson.features;
    if (geojson.type !== "FeatureCollection" || !Array.isArray(features) ||
        features.length === 0 || features.length > 1200) {
      return json(502, { error: "BOUNDARY_GEOJSON_INVALID" });
    }

    const payload = {
      metadata: {
        boundaryID: metadata.boundaryID,
        boundaryName: metadata.boundaryName,
        boundaryISO: metadata.boundaryISO,
        boundaryYearRepresented: metadata.boundaryYearRepresented,
        boundaryType: metadata.boundaryType,
        boundaryCanonical: metadata.boundaryCanonical,
        boundarySource: metadata.boundarySource,
        boundaryLicense: metadata.boundaryLicense,
        licenseSource: metadata.licenseSource,
        boundarySourceURL: metadata.boundarySourceURL,
        admUnitCount: metadata.admUnitCount,
      },
      geojson,
      attribution: "geoBoundaries — https://www.geoboundaries.org/; original source and licence are included in metadata.",
    };
    cache.set(boundaryLevel, { expiresAt: Date.now() + CACHE_TTL_MS, payload });
    return json(200, payload);
  } catch (error) {
    console.error("Public India boundary fetch failed", error instanceof Error ? error.message : "unknown");
    return json(502, { error: "BOUNDARY_FETCH_FAILED" });
  }
});
